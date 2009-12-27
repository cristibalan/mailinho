module Mail
  class Message
    def decoded_and_converted_to(encoding='UTF8')
      Iconv.conv("UTF8", charset, body.decoded)
    end

    def text_parts(sub_type)
      body.parts.map do |part| 
        if part.parts.empty?
          ct = part.content_type
          if ct.main_type == 'text' && ct.sub_type == sub_type && !part.attachment?
            part.decoded_and_converted_to
          end
        else
          part.text_parts(sub_type)
        end
      end.compact.flatten
    end

    def plain_body
      text_parts('plain').join("\n")
    end

    def html_body
      text_parts('html').join("\n")
    end

    def save_attachments(dir=nil)
      return if attachments.empty?

      dir = "#{dir}/"
      FileUtils.mkdir_p(dir)

      attachments.each do |a|
        fn = "#{dir}/#{a.filename}"
        next if File.exist? fn
        File.open(fn, "w") do |f|
          f << a.decoded
        end
      end
    end
  end
end
