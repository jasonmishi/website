# frozen_string_literal: true

Jekyll::Hooks.register :site, :pre_render do |site|
  next if ENV["JEKYLL_ENV"] == "production"

  env_path = File.join(site.source, ".env")
  unless ENV.key?("CV_PHONE") || !File.file?(env_path)
    File.foreach(env_path) do |line|
      next unless line.start_with?("CV_PHONE=")

      ENV["CV_PHONE"] = line.split("=", 2).last.to_s.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
      break
    end
  end

  phone = ENV["CV_PHONE"].to_s.strip
  next if phone.empty?

  cv = site.data.dig("cv", "cv")
  cv["phone"] = phone if cv.is_a?(Hash)

  basics = site.data.dig("resume", "basics")
  basics["phone"] = phone if basics.is_a?(Hash)
end
