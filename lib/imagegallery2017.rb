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
                  'folder, imgcount, title)', folder: nil, log: nil)

      @rsc, @wwwpath, @xslfile = [rsc, File.join(filepath, 'www'), xslfile]
      @log = log

      a = [@wwwpath, 'images']
      a << folder if folder
      
      @imagespath = File.join(*a)
      
      @log.info 'Gallery/initialize: imagespath: ' + @imagespath.inspect if @log
      FileUtils.mkdir_p @imagespath

      dxfilepath = File.join(@imagespath, 'dynarex.xml')
      
      if File.exists? dxfilepath then
        super(dxfilepath)
      else

        super(schema)
        self.order = :descending
        self.default_key = 'uid'
        self.title = 'Image gallery'
        self.xslt = xslfile

        self.save dxfilepath

      end
      
      if @log then
        @log.info 'Gallery/initialize: self.summary' + self.summary.inspect 
      end

    end

    def add_image(uploaded=nil)

      @log.info 'Gallery/add_image: active' if @log
      
      filename = uploaded[:filename].gsub(/ +/,'-')    
      file = File.join(@imagespath, filename)    
      File.write file, uploaded[:tempfile].read
          
      preview_file, desktop_file = @rsc.rmagick.resize file, 
          ['140x110','640x480']
      
      h = {original: filename, desktop: desktop_file, 
          preview: preview_file}

      self.create(h)
      self.save
      @log.info 'Gallery/add_image: saved' if @log
      
      return preview_file
    end
    
    def delete_image(id)
      self.delete id
    end

    def render()

      @log.info 'Gallery/render: active' if @log
      @log.info 'Gallery/render: self.to_xml' + self.to_xml if @log
      
      doc   = Nokogiri::XML(self.to_xml)
      
      if @log then
        @log.info "Gallery/render: self.summary: %s" % [self.summary.inspect]
      end
      
      xslt  = Nokogiri::XSLT(File.read(File.join(@imagespath, 
                                                 self.summary[:xslt])))
      xslt.transform(doc).to_s

    end

  end

  class IndexGallery < Gallery

    def initialize(rsc, filepath: '.', log: nil)

      FileUtils.mkdir_p File.join(filepath, 'www','images')
      FileUtils.mkdir_p File.join(filepath, 'www','xsl')
      super(rsc, filepath: filepath, log: log)

    end

    def render()
      
      @log.info 'IndexGallery/render: active' if @log
      
      File.write File.join(@wwwpath, 'index.html'), super()

    end

  end

  attr_reader :index, :gallery

  def initialize(rsc, basepath='.', log: nil, imgxsl: '../../xsl/images.xsl', 
                 default_folder: '../../svg/folder.svg')

    log.info 'ImageGallery/initialize: active' if log
    @rsc, @basepath = rsc, basepath 
    @index = IndexGallery.new rsc, filepath: @basepath, log: log
    @gallery = {}

    @default_folder, @log, @imgxsl = default_folder, log, imgxsl
    
    # load all the folders
    
    log.info 'ImageGallery/initialize: loading galleries' if log
    @index.all.each do |x|

      if x.folder.length > 0 then
        @gallery[x.folder] = Gallery.new rsc, 
            filepath: basepath, folder: x.folder, log: log
        log.info 'ImageGallery/initialize: loaded ' + x.folder if log
      end
      
    end

  end

  def add_image(upload_obj, folder=nil)
    
    @log.info 'ImageGallery/add_image: active; folder: ' + folder.to_s if @log
    
    if folder then 
      
      g = @gallery[folder]
      preview_file = g.add_image upload_obj
      
      rx = @index.find_by_folder folder
      rx.preview = preview_file
      rx.imgcount = g.all.length
      
      @index.save
      
    else
      @index.add_image upload_obj
    end
    
    @index.render
    
  end
  
  def browse(folder)
    (folder ? @gallery[folder] : @index).render
  end
  
  def delete_image(id, folder=nil)
    
    if folder then 
      
      g = @gallery[folder]
      g.delete_image id
      preview_file = g.all.any? ? g.all.first.preview : @default_folder
      
      rx = @index.find_by_folder folder
      rx.preview = preview_file
      rx.imgcount = g.all.length
      
      @index.save
      
    else
      @index.delete_image id
    end
    
    @index.render
    
  end

  def create_folder(title)    


    folder = title.downcase.gsub(/\W/,'-').gsub(/-{2,}/,'-').gsub(/^-|-$/,'')
    
    if @log then
      @log.info "ImageGallery/create_folder: title: %s basepath: %s" % 
          [title, @basepath.inspect]
    end
    fg = Gallery.new @rsc, filepath: @basepath, xslfile: @imgxsl, 
        folder: folder, log: @log
    fg.title = title
    fg.summary[:folder] = folder
    fg.save
    
    @log.info 'ImageGallery/create_folder: saved' if @log
    
    @gallery[folder] = fg
    @log.info 'ImageGallery/create_folder: folder: ' + folder.inspect if @log    
    @index.create preview: @default_folder, folder: folder, title: title
    @index.save
    @index.render
    
  end
  
  def delete_folder(folder)    

    @gallery.delete folder
    
    rx = @index.find_by_folder folder
    rx.delete
    @index.save
    @index.render
    
  end  
end
