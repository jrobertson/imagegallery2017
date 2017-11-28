#!/usr/bin/env ruby

# file: imagegallery2017.rb

# description: This is just a personal project on how I'm building an 
#              image gallery which uses XML to store filenames and an 
#              external DRb service to process images. It's designed 
#              to be used with Rack.

require 'dynarex'
require 'nokogiri'
require 'fileutils'


class ImageGallery2017

  class Gallery < Dynarex

    attr_reader :folder

    def initialize(rsc, filepath: '.', xslfile: '../xsl/index.xslt',  
          schema: 'images[title, folder]/image(original, desktop, preview, ' + 
                  'folder, imgcount, title)', folder: nil)

      @rsc, @wwwpath, @xslfile = [rsc, File.join(filepath, 'www'), xslfile]

      a = [@wwwpath, 'images']
      a << folder if folder
      
      @imagespath = File.join(*a)

      FileUtils.mkdir_p @imagespath

      dxfilepath = File.join(@imagespath, 'dynarex.xml')
      
      if File.exists? dxfilepath then
        super(dxfilepath)
      else

        super(schema)
        self.order = :descending
        self.title = 'Image gallery'
        self.xslt = xslfile

        self.save dxfilepath

      end

    end

    def add_image(uploaded=nil)

      filename = uploaded[:filename]    
      file = File.join(@imagespath, filename)    
      File.write file, uploaded[:tempfile].read
          
      preview_file, desktop_file = @rsc.rmagick.resize file, 
          ['140x110','640x480']
      
      h = {original: filename, desktop: desktop_file, 
          preview: preview_file}

      self.create(h)
      self.save

    end

    def render()

      doc   = Nokogiri::XML(self.to_xml)
      xslt  = Nokogiri::XSLT(File.read(File.join(@wwwpath, @xslt)))
      xslt.transform(doc).to_s

    end

  end

  class IndexGallery < Gallery

    def initialize(rsc, filepath: '.')

      FileUtils.mkdir_p File.join(filepath, 'www','images')
      FileUtils.mkdir_p File.join(filepath, 'www','xsl')
      super(rsc, filepath: filepath)

    end

    def render()
      
      File.write File.join(@wwwpath, 'index.html'), super()

    end

  end

  attr_reader :index, :gallery

  def initialize(rsc, basepath='.')

    @basepath, @rsc = basepath, rsc
    @index = IndexGallery.new rsc, filepath: @basepath
    @gallery = {}
    
    # load all the folders
    
    @index.all.each do |x|

      if x.folder.length > 0 then
        @gallery[x.folder] = Gallery.new @rsc, 
            filepath: basepath, folder: x.folder
      end
      
    end

  end

  def add_image(upload_obj, folder=nil)
    
    (folder ? @gallery[folder] : @index).add_image upload_obj
    
  end

  def create_folder(title)    

    folder = title.downcase.gsub(/\W/,'-').gsub(/-{2,}/,'-').gsub(/^-|-$/,'')

    fg = Gallery.new @rsc, filepath: @basepath, xslfile: '../xsl/images.xsl', 
        folder: folder
    fg.title = title
    fg.summary[:folder] = folder
    fg.save
    
    @gallery[folder] = fg    
    @index.create preview: '../svg/folder.svg', folder: folder, title: title
    @index.save

  end
end
