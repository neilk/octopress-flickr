octopress-flickr
================

Display Flickr images, video, and sets in Octopress blog posts.


## Synopsis

This plugin adds two new tags to your Octopress install. Use `flickr_image` to insert a specific image or video. 
Use `flickr_set` to insert an entire set.

``` md
  {% flickr_image id [preview-size [alignment [caption]] %}

  {% flickr_set id [preview-size ["desc"/"nodesc"]] %}
```

## Examples

``` md
{% flickr_image 3906771341 n right "whoa check out this \"Flickr\" thing!" %}

{% flickr_set 72157622329642662 t nodesc %}
```

## Install

Add these dependencies to your Octopress gemfile:

``` Rakefile
  gem 'flickraw'
  gem 'builder', '> 2.0.0'
  gem 'persistent_memoize'
```

And do a `gem install` from that directory.

Clone or otherwise obtain the files in this repository on your system. Copy or move the `.rb` and `.scss` files into
similar containing directories in your Octopress instance.

## Flickr API Key and Secret

You're going to need to obtain a [Flickr API key and secret](http://www.flickr.com/services/developer/api/).

Then, you'll need to ensure that they are in the environment variables `FLICKR_API_KEY` and `FLICKR_API_SECRET`, 
before you run `rake generate`. 


## Arguments

On Flickr, the id of the image is easily obtained from the URL. In this case the id is '3696071951'.

    http://www.flickr.com/photos/someuser/3696071951

The preview sizes must be specified as single-letter codes. Typically you will only need to remember that `m` is medium size,
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
 
The alignment is specified as `left`, `right`, or `center`, like the rest of Octopress.

The caption is a freeform string. If you want to have spaces in the caption, you may escape them directly with backslashes, or simply surround 
the entire argument with quotation marks. If your caption must also contain quotation marks, escape them with backslashes.

For photo sets, the final argument is not a caption, but controls whether the set description from Flickr is prepended to the entire set.

## Mobile 

The layout is responsive, so it should work well on tablets and mobile devices. Flickr Video may not work on iOS devices (although this is 
just a bug in the library; it's possible to obtain formats that will work on iOS).

## Fancybox

While this plugin can be used standalone it is far superior with the JavaScript image and gallery framework [Fancybox](http://fancyapps.com/fancybox/). (Instructions pending)


## TODOCUMENT

flickr icon - CSS data url?


