octopress-flickr
================

Display Flickr images, video, and sets in Octopress blog posts.

<p>
<a href="http://www.flickr.com/photos/brevity/8604488662/in/set-72157633123605507/">
<img src="http://farm9.staticflickr.com/8102/8604488662_0bca4dbd8d_m.jpg" title="octopress-flickr fancybox previews" style="width: 240px; height: 219px;">
</a>
<a href="http://www.flickr.com/photos/brevity/8604488436/in/set-72157633123605507/">
<img src="http://farm9.staticflickr.com/8402/8604488436_9144764e1d_m.jpg" title="Simple image" style="width: 240px; height: 216px;">
</a>
<a href="http://www.flickr.com/photos/brevity/8810723278/in/set-72157633123605507/">
<img src="http://farm9.staticflickr.com/8140/8810723278_6e9deb0a6a_m.jpg" title="Responsive design for mobile browsers" style="width: 128px; height: 240px;">
</a>
<a href="http://www.flickr.com/photos/brevity/8603387237/in/set-72157633123605507/">
<img src="http://farm9.staticflickr.com/8536/8603387237_83511ec935_m.jpg" title="Sets in &quot;slideshow&quot; mode" style="width: 240px; height: 185px;">
</a>
<a href="http://www.flickr.com/photos/brevity/8604487732/in/set-72157633123605507/">
<img src="http://farm9.staticflickr.com/8250/8604487732_e20492a366_m.jpg" title="Sets" style="width: 240px; height: 216px;">
</a>
<a href="http://www.flickr.com/photos/brevity/8799830039/in/set-72157633123605507/">
<img src="http://farm6.staticflickr.com/5455/8799830039_15720b1f00_m.jpg" title="Works with themes" style="width: 240px; height: 164px;">
</a>
</p>

## Synopsis

``` md
{% flickr_image 7779670214 %}

{% flickr_image 3115811489 t %}

{% flickr_image 3906771341 n right "whoa check out this \"Flickr\" thing!" %}

{% flickr_set 72157622329642662 t nodesc %}
```

## Setup

### Obtain a Flickr API key and secret

You're going to need to obtain a [Flickr API key and secret](http://www.flickr.com/services/developer/api/).

Then, you'll need to ensure that they are available to Octopress. You can do this in two ways:

1. put them in the environment variables `FLICKR_API_KEY` and `FLICKR_API_SECRET`, 
2. add them to your `config.yml` like so:

``` yaml
flickr:
  api_key: <api_key>
  shared_secret: <shared_secret>
```

### Install the plugin

Add these dependencies to your Octopress gemfile:

``` Rakefile
  gem 'flickraw'
  gem 'builder', '> 2.0.0'
  gem 'persistent_memoize'
```

Do a `bundle install` from that directory.

Download the files in this repository. Copy the `.rb` and `.scss` files into the corresponding directories in your Octopress instance. This might 
work:

``` bash
$ cd octopress-flickr
$ find . \( -name '*.rb' -o -name '*.scss' \) -exec cp {} /path/to/octopress/{} \;
```

Finally, in your Octopress instance, make sure that `sass/screen.scss` ends with the following line.

``` sass
@import "plugins/**/*";
```

And, you're done. You can start using the new tags right away. (But, see below for how to install Fancybox,
which will greatly improve the UI).

## How to use the tags

This plugin adds two new tags to your Octopress install. Use `flickr_image` to insert a specific image or video. 
Use `flickr_set` to insert an entire set. The arguments for these tags are:

``` md
  {% flickr_image id [preview-size [alignment [caption]] %}

  {% flickr_set id [preview-size [desc|nodesc]] %}
```

On Flickr, the **id** of the image is easily obtained from the URL. In this case the id is '3696071951'.

    http://www.flickr.com/photos/someuser/3696071951

The **preview-size** must be specified as a single-letter code. Typically you will only need to remember that `m` is medium size,
and `z` will probably fill the entire screen. Here is the full list of sizes you can use, with their common name on Flickr,
and then the maximum width or height of that image.

* **o**  : "Original", no maximum dimension
* **b**  : "Large", 1024px
* **z**  : "Medium 640", 640px
* **n**  : "Small 320", 320px
* **m**  : "Small", 240px,
* **t**  : "Thumbnail", 100px
* **q**  : "Large Square", 150px
* **s**  : "Square", 75px

The **alignment** is specified as `left`, `right`, or `center`, like the rest of Octopress.

The **caption** is a freeform string. If you want to have spaces in the caption, you may escape them directly with backslashes, or simply surround 
the entire argument with quotation marks. If your caption must also contain quotation marks, escape them with backslashes.

For photo sets, the final argument is not a caption, but controls whether the set description from Flickr is prepended to the entire set.

## I updated my photos on Flickr; why aren't they updating in Octopress?

This plugin caches API results and generated HTML in a `.flickr-cache` directory in your Octopress root. This makes sure that we aren't wasting
time redownloading information from Flickr every time you update your blog. 

But, in case the information about those photos changes, to see updates, you need to remove those cache files and then `rake generate`.

At the moment it is not easy to remove the caches for some photos or sets and not others. Some command-line fu can help - this removes cache
files younger than one hour:

``` sh
find .flickr-cache/ -type f -mtime -1h | xargs rm
```

You also might want to modify your Rakefile to clean out this cache. If your Rakefile is typical, you need to change the `:clean` target to look 
like this:

``` Rakefile
desc "Clean out caches: .pygments-cache, .gist-cache, .sass-cache, .flickr-cache"
task :clean do
  rm_rf [".pygments-cache/**", ".gist-cache/**", ".sass-cache/**", "source/stylesheets/screen.css", ".flickr-cache/**"]
end
```


## Fancybox 

While this plugin can be used standalone, it is far superior with the JavaScript lightbox and slideshow library 
[Fancybox](http://fancyapps.com/fancybox/). Here's how to set it up.

First, download and uncompress [Fancybox](http://fancyapps.com/fancybox/).
In the directory which was created from uncompressing Fancybox,
copy the contents of the `source` directory to the `source/fancybox`
directory in your Octopress install. It might look like this:

``` sh
$ unzip fancyapps-fancyBox-v2.1.4-0-somehash.zip
$ cd fancyapps-fancyBox-somehash
$ cp -R source /path/to/octopress/source/fancybox
```

Next, in the files you downloaded from this `octopress-flickr` respository, copy the file
`source/_includes/custom/fancybox_head.html` to the corresponding directory in your Octopress install.

Next, in your Octopress install, in the file `source/_includes/head.html`, add the following line. This line should be after loading jQuery, but 
before custom/head.html.

``` markdown
{% include custom/fancybox_head.html %} 
```

Finally, change the following lines in `sass/base/_theme.scss`.

``` diff
body {
-  > div {
+  > #main {
     border-bottom: 1px solid $page-border-bottom;
-    > div {
+    > #content {
       border-right: 1px solid $sidebar-border;
     }
   }
```

That should do it!

For efficiency, you might want to merge the CSS into the SASS system, but you're on your own there.

## HTML5

This plugin tries to generate standards-compliant, modern HTML5. That means it uses tags like `<figure>` and `<figcaption>` and such. This may not look right in very old browsers, 
but it seems to work in anything better than IE7. 

## Be nice

Flickr allows you to embed images in your blog, but they request you always link back to the source image. This plugin handles that for you by
default, so don't mess with it.

Obviously using your own images is fine, but be aware that you don't always have the rights to republish images on your own blog. If you want to
be sure, ask the author's permission. Or use Flickr's [advanced search](https://www.flickr.com/search/advanced/) to find [Creative Commons](https://creativecommons.org)-licensed media. 



## Acknowledgements

Originally based on [this gist](https://gist.github.com/danielres/3156265) by Daniel Reska.
