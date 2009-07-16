require 'mini_magick'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Processors
      module MiniMagickProcessor
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end
 
        module ClassMethods
          # Yields a block containing an MiniMagick Image for the given binary data.
          def with_image(file, &block)
            begin
              binary_data = file.is_a?(MiniMagick::Image) ? file : MiniMagick::Image.from_file(file) unless !Object.const_defined?(:MiniMagick)
            rescue
              # Log the failure to load the image.
              logger.debug("Exception working with image: #{$!}")
              binary_data = nil
            end
            block.call binary_data if block && binary_data
          ensure
            !binary_data.nil?
          end
        end
 
      protected
        def process_attachment_with_processing
          return unless process_attachment_without_processing
          with_image do |img|
            resize_image_or_thumbnail! img
            self.width = img[:width] if respond_to?(:width)
            self.height = img[:height] if respond_to?(:height)
            callback_with_args :after_resize, img
          end if image?
        end
 
        # Performs the actual resizing operation for a thumbnail
        def resize_image(img, size)
          size = size.first if size.is_a?(Array) && size.length == 1
          if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
            if size.is_a?(Fixnum)
              size = [size, size]
              img.resize(size.join('x'))
            else
              img.resize(size.join('x') + '!')
            end
          else
            n_size = [img[:width], img[:height]] / size.to_s
            if size.ends_with? "!"
              aspect = n_size[0].to_f / n_size[1].to_f
              ih, iw = img[:height], img[:width]
              w, h = (ih * aspect), (iw / aspect)
              w = [iw, w].min.to_i
              h = [ih, h].min.to_i
              if ih > h
                shave_off =  ((ih - h) / 2).round
                img.shave("0x#{shave_off}")
              end
              if iw > w
                shave_off = ((iw - w ) / 2).round
                img.shave("#{shave_off}x0")
              end
              img.resize(size.to_s)
            else
              img.resize(size.to_s)
            end
            self.temp_path = img
          end
        end

        def calculate_offset(image_width,image_height,image_aspect,thumb_width,thumb_height,thumb_aspect)
        # only crop if image is not smaller in both dimensions

          # special cases, image smaller in one dimension then thumbsize
          if image_width < thumb_width
            offset = (image_height / 2) - (thumb_height / 2)
            command = "#{image_width}x#{thumb_height}+0+#{offset}"
          elsif image_height < thumb_height
            offset = (image_width / 2) - (thumb_width / 2)
            command = "#{thumb_width}x#{image_height}+#{offset}+0"

          # normal thumbnail generation
          # calculate height and offset y, width is fixed                 
          elsif (image_aspect <= thumb_aspect or image_width < thumb_width) and image_height > thumb_height
            height = image_width / thumb_aspect
            offset = (image_height / 2) - (height / 2)
            command = "#{image_width}x#{height}+0+#{offset}"
          # calculate width and offset x, height is fixed
          else
            width = image_height * thumb_aspect
            offset = (image_width / 2) - (width / 2)
            command = "#{width}x#{image_height}+#{offset}+0"
          end
          # crop image
          command
        end


      end
    end
  end
end