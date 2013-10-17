require "builder"
require "cgi"
require "flickraw"
require "persistent_memoize"

# CAUTION: This entire plugin is an XSS vector, as we accept HTML from the Flickr API and
# republish it without any transformation or sanitization on our site. If someone can control
# the HTML in titles or descriptions on Flickr they can inject arbitrary HTML into our site.
# The risk is relatively low, since Flickr goes to great lengths to sanitize their inputs. But
# an attacker could exploit some difference between the two sites (encoding, maybe) to do XSS.


module TagUtil 
  
  # helper for parseMarkup
  def self.appendChar(args, i, c)
    if args[i] == nil 
      args[i] = c
    else 
      args[i] << c
    end
  end

  # parse a string of arguments separated by spaces
  # arguments may be quoted to capture spaces
  # backslash to escape delimiters or spaces
  # e.g. 
  #   <empty string>     -> []
  #   <spaces>           -> []
  #   foo                -> ["foo"]
  #   foo bar            -> ["foo", "bar"]
  #     foo   bar        -> ["foo", "bar"]
  #   foo 'bar quux'     -> ["foo", "bar quux"]
  #   foo bar\ quux      -> ["foo", "bar quux"]
  #   foo "'bar quux'"   -> ["foo", "'bar quux'"]
  #   foo "\"bar quux\"" -> ["foo", "\"bar quux\""]
  #
  def self.parseMarkup(markup)
    escaped = false
    inQuote = nil
    args = []
    i = 0
    markup.split("").each do |c|
      if escaped 
        self.appendChar(args, i, c)
        escaped = false
      else
        if c == '\\'
          escaped = true 
        else 
          if inQuote != nil
            if c == inQuote
              i += 1
              inQuote = nil
            else
              self.appendChar(args, i, c)
            end
          else
            if c.match(/['"]/) 
              inQuote = c
            elsif c.match(/\s/) 
              if args[i] != nil
                i += 1
              end
            else
              self.appendChar(args, i, c)
            end
          end
        end
      end
    end

    return args
  end

end



class FlickrCache
  def self.cacheFile(name)
    cache_folder     = File.expand_path "../.flickr-cache", File.dirname(__FILE__)
    FileUtils.mkdir_p cache_folder
    return "#{cache_folder}/#{name}"
  end
end

class FlickrApiCached
  def initialize 
    @photos = FlickrApiCachedPrefix.new(:photos)
    @photosets = FlickrApiCachedPrefix.new(:photosets)
  end

  def photos
    return @photos
  end

  def photosets
    return @photosets
  end
end

class FlickrApiCachedPrefix
  include PersistentMemoize

  def initialize(sym)
    @prefix = flickr.send(sym)
    memoize(:method_missing, FlickrCache.cacheFile("api_#{sym}"))
  end

  def method_missing(sym, *args, &block)
    @prefix.send sym, *args, &block
  end

end

class FlickrPhotoHtml

  def initialize(id, params)
    @id = id
    @size = params['size'] || 's'

    case @size
    when 'o'
      @zoom_size = 'o'
    when 'z', 'b'
      @zoom_size = 'b'
    else
      @zoom_size = 'z'
    end

    if params['title'].nil? or params['title'].empty?
      @title = "Untitled photo"
    else 
      @title = params['title']
    end

    unless params['class'].nil? or params['class'].empty?
      @klass = params['class']
    end

    if params['desc'].nil? or params['desc'].empty?
      @desc = ""
    else
      @desc = params['desc']
    end

    unless params['gallery_id'].nil? or params['gallery_id'].empty?
      @gallery_id = params['gallery_id']
    end

    unless params['page_url'].nil? or params['page_url'].empty?
      @page_url = params['page_url']
    end

    unless params['username'].nil? or params['username'].empty?
      @username = params['username']
    end

    # get the dimensions
    @sizes = flickrCached.photos.getSizes(photo_id: @id)
    @src, @width, @height = FlickrSizes.getSourceAndDimensionsForSize(@sizes, @size)
  end

  def getAnchorAttrs(dataTitleId)
    zoomUrl, zoomWidth, zoomHeight = FlickrSizes.getSourceAndDimensionsForSize(@sizes, @zoom_size)
    return {
      'href' => zoomUrl,
      'class' => 'fancybox',
      'data-title-id' => dataTitleId,
      'data-media' => 'photo'
    }
  end

  def cssAttrsToStyle(cssAttrs)
    cssAttrs.map { |(k, v)|
        k.to_s + ': ' + v.to_s + ';'
      }.join " "
  end

  def icon(x)
    # do nothing
  end

  def toHtml
    imgAttrs = {src: @src, title: @title}
    imgCssAttrs = {}

    figureClass = ['flickr-thumbnail']
    unless @klass.nil? or @klass.empty?
      figureClass.push(@klass)
    end
    figureAttrs = { 'class' => figureClass.join(" ") }
    figureCssAttrs = {}

    # The next bit is tricky - working around various browser bugs, and undesirable behavior.
    # Desiderata
    #   images and their captions should be surrounded by a nice visual offset, white border with  
    #     drop shadow. This is a uniform border around the image if no caption, but surrounds caption if it
    #     exists
    #   large images should uniformly scale in width and height if viewport is narrow.
    #   avoid an annoying webkit bug where many inline-blocks, without explicit height and width, sometimes
    #    shrink to zero size - this happens with big sets
    # 
    # Solution : 
    #   small images: include explicit width and height - avoids layout bug with sets
    #       Also include explicit width for figures for smaller images 
    #   large images: 
    #        Do NOT include explicit width & height for largeish images, because due to other CSS that makes such 
    #        images want to be 100% of the width, they scale the width only. If there is an explicit height then 
    #        it is retained, thus we get a distorted image. Instead, use the inline-block trick here, because we don't care about 
    #        laying out zillions of little images.
    #
    # We also add width to the figure element so it doesn't extend for the entire width, if small.
    # And we make the figure an inline-block if it IS bigger than 450, so it snaps to the size of the image 
    if (not (@width.nil?)) and @width.to_i < 450
      imgCssAttrs['width'] = figureCssAttrs['width'] = @width.to_s + 'px';
      unless @height.nil?
        imgCssAttrs['height'] = @height.to_s + 'px';
      end
    else 
      figureCssAttrs['display'] = 'inline-block'
    end

    imgAttrs["style"] = self.cssAttrsToStyle(imgCssAttrs)
    figureAttrs["style"] = self.cssAttrsToStyle(figureCssAttrs)


    xmlBuffer = ""
    x = Builder::XmlMarkup.new( :target => xmlBuffer )

  
    dataTitleId = 'flickr-photo-' + @id 

    anchorAttrs = self.getAnchorAttrs(dataTitleId) 
    if @gallery_id
      anchorAttrs['rel'] = @gallery_id;
    end
    captionAttrs = {
      'id' => dataTitleId
    }

    x.figure(figureAttrs) { |x| 
      x.a(anchorAttrs) { |x|
        x.img(imgAttrs)
        self.icon(x)
      }
      x.figcaption(captionAttrs) { |x|
        x.h1{ |x|
          x.a('class' => 'flickr-link', 'href' => @page_url) { |x| x << @title }
          if @username
            x << " by "
            x << @username
          end
        }
        x.div({'class' => 'description'}) { |x| 
          x << @desc
        } 
      }
    }
   
    xmlBuffer
  end
end


class FlickrVideoPreviewHtml < FlickrPhotoHtml

  def initialize(id, params)
    super(id, params)
    @secret = params['secret']
    @origWidth = params['origWidth']
    @origHeight = params['origHeight']
    @contentId = 'flickr-video-content-' + @id
    @klass = 'video-preview'
    @zoom_size = 'z'
  end

  def getAnchorAttrs(dataTitleId)
    return {
      'href' => @page_url,
      'class' => 'fancybox',
      'data-title-id' => dataTitleId,
      'data-media' => 'video',
      'data-content-id' => '#' + @contentId
    }
  end

  def getZoomLink
    return @page_url
  end

  def icon(x) 
    x.span( { 
      'class' => 'video-icon', 
    } ) {
      x << '&#x25b6;'
    }
  end

  def toHtml
    html = ""
    html << super 
    html << "<div style='display:none'><div id='#{@contentId}'>"
    html << FlickrVideoHtml.new(@id, @secret, @zoom_size, @origWidth, @origHeight).toHtml
    html << "</div></div>"          
    html
  end
end

class FlickrVideoHtml
  @@type="application/x-shockwave-flash" 
  @@playerSwf="http://www.flickr.com/apps/video/stewart.swf?v=109786" 
  @@classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"
  @@bgcolor="#000000" 
  @@allowfullscreen="true" 
  @@size = '__video__'

  def initialize(id, photoSecret, size, origWidth, origHeight)
    @id = id
    @photoSecret = photoSecret
    @size = size
    @origWidth = origWidth
    @origHeight = origHeight

    @sizes = flickrCached.photos.getSizes(photo_id: @id)
    @src, dummy1, dummy2 = FlickrSizes.getSourceAndDimensionsForSize(@sizes, 'site_mp4')
    @poster, @width, @height = FlickrSizes.getSourceAndDimensionsForSize(@sizes, @size)
  end

  def toHtml
    width, height = FlickrSizes.calculateDimensions(@size, @origWidth, @origHeight)

    flashvarsHash = {
      intl_lang: 'en-us',
      photo_secret: @photoSecret,
      photo_id: @id
    }
    flashvars = flashvarsHash.map { | (k, v) | 
      CGI.escape(k.to_s) + '=' + CGI.escape(v.to_s)
    }.join "&"

    xmlBuffer = ""
    x = Builder::XmlMarkup.new( :target => xmlBuffer )

    x.object( { 'type' => @@type, 
                'width' => width, 
                'height' => height,
                'data' => @@playerSwf,
                'classid' => @@classid } ) { |x|
      x.param( { 'name' => 'flashvars', 'value' => flashvars } )
      x.param( { 'name' => 'movie', 'value' => @@playerSwf } )
      x.param( { 'name' => 'bgcolor', 'value' => @@bgcolor } )
      x.param( { 'name' => 'allowFullScreen', 'value' => @@allowfullscreen } )
      x.embed( { 'type' => @@type, 
                 'src' => @@playerSwf, 
                 'bgcolor' => @@bgcolor,
                 'allowfullscreen' => @@allowfullscreen,
                 'flashvars' => flashvars,
                 'width' => width,
                 'height' => height } )
    }

    xmlBuffer
  end
end


class FlickrSizes 
  @@sizes = [    
    {code: "original_video", label: "Original Video", max: nil },
    {code: "mobile_mp4", label: "Mobile MP4", max: 480 },
    {code: "site_mp4", label: "Site MP4", max: 640 },
    {code: "video_player", label: "Video Player", max: 640 },
    {code: "o", label: "Original", max: nil },
    {code: "b", label: "Large", max: 1024 },
    # {code: "c", label: "Medium 800", max: 75 },  # FlickrRaw doesn't know about this size
    {code: "z", label: "Medium 640", max: 640 },
    {code: "__NONE__", label: "Medium", max: 500 },
    {code: "n", label: "Small 320", max: 320 },
    {code: "m", label: "Small", max: 240 },
    {code: "t", label: "Thumbnail", max: 100 },
    {code: "q", label: "Large Square", max: 150 },
    {code: "s", label: "Square", max: 75 }
  ]

  def self.sizes
    @@sizes
  end

  def self.getSourceAndDimensionsForSize(sizes, size)
    # try getting the size we wanted, then try getting ANY size, going from largest to smallest
    sizeCodesToTry = [ size ] + @@sizes.map{ |s| s[:code] }
    sizeInfo = nil
    for code in sizeCodesToTry
      sizeInfo = pickSize(sizes, code)
      if sizeInfo
        break
      end
    end
    if (sizeInfo.nil?)
      raise "could not get a size"
    end
    [ sizeInfo["source"], sizeInfo["width"], sizeInfo["height"] ]
  end

  def self.getSizeByCode(code) 
    @@sizes.select{ |s| s[:code] == code }[0]
  end

  def self.pickSize(sizes, desiredSizeCode)
    desiredSizeLabel = self.getSizeByCode(desiredSizeCode)[:label]
    sizes.select{ |item| item["label"] == desiredSizeLabel }[0]
  end

  def self.calculateDimensions(desiredSizeCode, width, height)
    width = width.to_i
    height = height.to_i
    size = self.getSizeByCode(desiredSizeCode)
    factor = 1
    unless size == nil or size[:max].nil?
      factor = size[:max].to_f / [width, height].max
    end
    return [width, height].map { |dim| (dim * factor).to_i }
  end
end

class FlickrImageTag < Liquid::Tag
  include PersistentMemoize

  # options we want:
  # preview size
  # class=right/left/center
  # caption
  # credit (via config)  
  # popup description
  def initialize(tag_name, markup, tokens)
    super
    
    args = TagUtil.parseMarkup(markup)
    @id   = args[0]
    @size = args[1] || 'm'
    @klass = args[2]
    @desc = args[3]

    unless FlickrSizes.getSizeByCode(@size)
      raise "did not recognize photo size: #{@size}";
    end
    
    memoize(:getHtml, FlickrCache.cacheFile("photo"))
  end

  def render(context)
    self.getHtml(@id, @size, @klass, @desc)
  end

  def getHtml(id, size, klass, desc)
    info = flickrCached.photos.getInfo(photo_id: id)
    if desc.nil? or desc.empty?
      desc = info['description']
    end
    
    html = "HTML should go here"
    params = {
        "size" => size,
        "secret" => info['secret'],
        "username" => info['owner']['username'],
        "page_url" => FlickRaw.url_photopage(info),
        "title" => info['title'], 
        "class" => klass, 
        "desc" => desc,
      }
    if info['video']
      # params['origWidth'] = info['video']['width']
      # params['origHeight'] = info['video']['height']
      # html = FlickrVideoHtml.new(@id, params).toHtml
      html = FlickrVideoHtml.new(@id, 
                                 info['secret'], 
                                 @size, 
                                 info['video']['width'],
                                 info['video']['height'] ).toHtml
    else 
      html = FlickrPhotoHtml.new(@id, params).toHtml
    end

    html
  end

end

class FlickrSetTag < Liquid::Tag
  include PersistentMemoize

  def initialize(tag_name, markup, tokens)
    super
    args = TagUtil.parseMarkup(markup)
    @id = args[0]
    @size = args[1] || 'm'
    @showSetDesc = true
    if (args[2] == 'nodesc')
      @showSetDesc = false 
    end

    unless FlickrSizes.getSizeByCode(@size)
      raise "did not recognize photo size for sets: #{@size}";
    end

    memoize(:getHtml, FlickrCache.cacheFile("set"))
  end

  def render(context)
    getHtml(@id, @size, @showSetDesc)
  end

  def getHtml(id, size, showSetDesc)
    info = flickrCached.photosets.getInfo(photoset_id: id)
    
    outputHtml = []

    # assume the title is in the blog post title?
    # titleHtml = '<p>' + info.title + '</p>'
    # outputHtml.push(titleHtml)
    
    if showSetDesc and not info.description.empty?
      outputHtml.push('<p>' + info.description.gsub(/\n/, '<br/>') + '</p>')
    end

    setPhotosHtml = [];
    # pathalias will give us pretty urls to the photo page
    # note, you have to request 'path_alias' but the returned prop is "pathalias"
    apiExtras = ['url_' + size, 'url_o', 'path_alias', 'media'].join(',');
    response = flickrCached.photosets.getPhotos(photoset_id: id, extras: apiExtras)
    response['photo'].each do |photo|
      params = {
        "size" => size,
        "secret" => photo['secret'],
        "width" => photo["width_" + size],
        "height" => photo["height_" + size],
        "origWidth" => photo["width_o"],
        "origHeight" => photo["height_o"],
        "title" => photo["title"],
        # this doesn't call the api, it constructs the URL from info retrieved
        # Not using FlickRaw.url_photopage() because when user doesn't define pathalias, no owner in photo record,
        # so can't construct URL. (bug in Flickr API?)
        "page_url" => FlickRaw.url_photostream(response) + photo.id,
        "gallery_id" => "flickr-set-" + id
      }
      photoInfoResponse = flickrCached.photos.getInfo(photo_id: photo["id"])
      params["desc"] = photoInfoResponse["description"] 
      params["username"] = photoInfoResponse["owner"]["username"] 
      html = "<!-- thumbail here -->"
      if photo['media'] == 'video'
        html = FlickrVideoPreviewHtml.new(photo["id"], params).toHtml
      else
        html = FlickrPhotoHtml.new(photo["id"], params).toHtml
      end
      setPhotosHtml.push(html)
    end

    setHtml = '<section class="flickr-set">' + setPhotosHtml.join + '</section>'
    outputHtml.push(setHtml)

    outputHtml.join
  end
  

end

begin
  FlickRaw.api_key        = ENV['FLICKR_API_KEY'] || Jekyll.configuration({})['flickr']['api_key']
  FlickRaw.shared_secret  = ENV['FLICKR_API_SECRET'] || Jekyll.configuration({})['flickr']['shared_secret']
rescue
  $stderr.print("flickr.rb could not be configured. See documentation.\n")
end

def flickrCached; $flickrCached ||= FlickrApiCached.new end
Liquid::Template.register_tag("flickr_image", FlickrImageTag)
Liquid::Template.register_tag("flickr_set", FlickrSetTag)
