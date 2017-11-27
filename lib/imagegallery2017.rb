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

    def initialize(rsc, filepath: '.', xslfile: 'index.xslt',  
          schema: nil, title: nil)

      @rsc = rsc
      @wwwpath = File.join(filepath, 'www')
      @xslfile = xslfile

      @folder = ''

      a = [@wwwpath, 'images']

      if title then

        @folder = title.downcase.gsub(/\W/,'-').gsub(/-{2,}/,'-')\
          .gsub(/^-|-$/,'')

        a << @folder

      end
      
      @imagespath = File.join(*a)

      FileUtils.mkdir_p @imagespath

      dxfilepath = File.join(@imagespath, 'dynarex.xml')

      if schema then

        super(schema)
        self.order = :descending
        self.title = title || 'Image gallery'
        self.summary[:folder] = @folder
        self.save dxfilepath

      else
        super(dxfilepath)
      end

    end

    def add_entry(uploaded=nil)

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
      xslt  = Nokogiri::XSLT(File.read(File.join(@wwwpath, @xslfile)))
      xslt.transform(doc).to_s

    end

  end

  class IndexGallery < Gallery

    def initialize(rsc, filepath: '.')

      FileUtils.mkdir_p File.join(filepath, 'www','images')
      FileUtils.mkdir_p File.join(filepath, 'www','xsl')
      super(rsc, filepath: filepath, schema: 'images[title, folder]/image' + 
        '(original, desktop, preview, path, imgcount, title)')

    end

    def modify_entry(id)
      #self.find_by_id()
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

  end

  def add_entry(params)
    @index.add_entry params
  end

  def create_folder(title)    

    fg = Gallery.new @rsc, schema: 'images[title, folder]/image(original, ' +
      'desktop, preview, title)', filepath: @basepath, title: title, 
       xslfile: 'images.xsl'

    @gallery[fg.folder] = fg    
    @index.create preview: '../svg/folder.svg', path: fg.folder, title: title
    @index.save

  end
end
