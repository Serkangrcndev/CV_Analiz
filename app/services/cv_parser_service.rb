require 'zip'
require 'base64'

class CVParserService
  def initialize(file_path, original_filename)
    @file_path = file_path
    @filename = original_filename
  end

  def parse
    raw_text = extract_text
    clean_text = clean_raw_text(raw_text)
    
    ai_parsed = nil
    if LLMService.configured?
      begin
        ai_parsed = LLMService.parse_cv_text(clean_text)
      rescue => e
        warn "AI parsing failed, falling back to regex parser: #{e.message}"
      end
    end

    if ai_parsed && ai_parsed.is_a?(Hash) && ai_parsed['personal_info']
      personal_info = ai_parsed['personal_info'] || {}
      personal_info['photo'] = extract_profile_photo
      
      education = (ai_parsed['education'] || []).map do |edu|
        {
          'institution' => edu['institution'] || 'Institution Details Unspecified',
          'degree' => edu['degree'] || 'Degree Unspecified',
          'year' => edu['year']&.to_s,
          'gpa' => edu['gpa']&.to_s
        }
      end

      work_experience = (ai_parsed['work_experience'] || []).map do |exp|
        {
          'role' => exp['role'] || 'Professional Position',
          'company' => exp['company'] || 'Company Details Unspecified',
          'duration' => exp['duration']&.to_s || '',
          'description' => exp['description'] || ''
        }
      end

      projects = (ai_parsed['projects'] || []).map do |proj|
        {
          'title' => proj['title'] || 'Project Details Unspecified',
          'description' => proj['description'] || ''
        }
      end

      skills = ai_parsed['skills'] || []

      {
        filename: @filename,
        parsed_text: clean_text,
        personal_info: personal_info,
        education: education,
        work_experience: work_experience,
        skills: skills,
        projects: projects
      }
    else
      sections = segment_sections(clean_text)
      personal_info = extract_personal_info(clean_text, sections)
      personal_info['photo'] = extract_profile_photo
      
      {
        filename: @filename,
        parsed_text: clean_text,
        personal_info: personal_info,
        education: parse_education(sections['education']),
        work_experience: parse_experience(sections['experience']),
        skills: parse_skills(sections['skills'], clean_text),
        projects: parse_projects(sections['projects'])
      }
    end
  end

  private

  def extract_text
    ext = File.extname(@filename).downcase
    case ext
    when '.pdf'
      extract_pdf
    when '.docx'
      extract_docx
    else
      extract_txt
    end
  rescue => e
    warn "Failed to parse file #{@filename}: #{e.message}"
    # Fallback to standard text reading
    extract_txt rescue ""
  end

  def extract_pdf
    reader = PDF::Reader.new(@file_path)
    reader.pages.map(&:text).join("\n")
  end

  def extract_docx
    doc = Docx::Document.open(@file_path)
    doc.paragraphs.map(&:text).join("\n")
  end

  def extract_txt
    File.read(@file_path, encoding: 'utf-8') rescue File.read(@file_path, encoding: 'iso-8859-1')
  end

  def clean_raw_text(text)
    return "" if text.nil?
    text.gsub(/\r\n?/, "\n")
        .gsub(/[^\S\n]+/, " ") # normalize spaces, keep newlines
  end

  def segment_sections(text)
    lines = text.split("\n")
    sections = Hash.new { |h, k| h[k] = [] }
    current_section = 'intro'

    # Common section header keywords (regex)
    headers = {
      'education' => /^\s*(education|educational background|eğitim|eğitim bilgileri)\s*$/i,
      'experience' => /^\s*(experience|work experience|employment history|professional experience|iş deneyimi|deneyim|deneyimleri)\s*$/i,
      'projects' => /^\s*(projects|personal projects|academic projects|projeler|projelerim)\s*$/i,
      'skills' => /^\s*(skills|technical skills|technologies|beceriler|yetenekler|teknik beceriler)\s*$/i,
      'certificates' => /^\s*(certifications|certificates|sertifikalar|lisanslar ve sertifikalar)\s*$/i,
      'languages' => /^\s*(languages|yabancı diller|diller)\s*$/i
    }

    lines.each do |line|
      trimmed = line.strip
      next if trimmed.empty?

      matched_header = nil
      headers.each do |key, regex|
        if trimmed =~ regex
          matched_header = key
          break
        end
      end

      if matched_header
        current_section = matched_header
      else
        sections[current_section] << trimmed
      end
    end

    sections
  end

  def extract_personal_info(text, sections)
    info = {}
    
    # Extract Email
    email_regex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
    info['email'] = text.scan(email_regex).first

    # Extract Phone
    phone_regex = /(?:\+?(\d{1,3}))?[\s.-]?\(?(\d{3})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})/
    info['phone'] = text.scan(phone_regex).map { |m| m.compact.join("-") }.first

    # Extract GitHub & LinkedIn
    linkedin_regex = /(?:https?:\/\/)?(?:www\.)?linkedin\.com\/in\/([a-zA-Z0-9_-]+)/i
    github_regex = /(?:https?:\/\/)?(?:www\.)?github\.com\/([a-zA-Z0-9_-]+)/i
    
    info['linkedin'] = text.scan(linkedin_regex).flatten.first
    info['github'] = text.scan(github_regex).flatten.first

    # Extract Name (Guess from the top of the intro or the first line)
    intro_lines = sections['intro'] || []
    candidate_name = "Candidate"
    
    intro_lines.each do |line|
      trimmed = line.strip
      # Skip lines that look like emails, urls, or phone numbers
      next if trimmed =~ email_regex || trimmed =~ /linkedin/i || trimmed =~ /github/i || trimmed =~ phone_regex || trimmed.split.size < 2 || trimmed.split.size > 4
      candidate_name = trimmed
      break
    end
    info['name'] = candidate_name

    info
  end

  def parse_education(lines)
    return [] if lines.nil? || lines.empty?
    
    education_list = []
    current_entry = nil

    lines.each do |line|
      # Look for university name keywords
      if line =~ /(university|college|institute|okulu|üniversitesi|lisesi|univ)/i
        education_list << current_entry if current_entry
        current_entry = {
          'institution' => line,
          'degree' => 'Bachelor of Science', # Default fallback
          'year' => nil,
          'gpa' => nil
        }
      elsif current_entry
        # Extract Degree
        if line =~ /(bachelor|master|phd|associate|doktora|yüksek lisans|lisans|bsc|msc|ba|ma)/i
          current_entry['degree'] = line
        end
        # Extract Graduation Year (e.g. 2018 - 2022 or 2022)
        if line =~ /\b(?:19|20)\d{2}\b/
          years = line.scan(/\b(?:19|20)\d{2}\b/)
          current_entry['year'] = years.last
        end
        # Extract GPA (e.g., 3.4/4.0 or GPA: 3.5)
        if line =~ /(gpa|ortalama)\s*:?\s*([0-3]\.\d{1,2}|4\.0)/i
          current_entry['gpa'] = line.scan(/(gpa|ortalama)\s*:?\s*([0-3]\.\d{1,2}|4\.0)/i).flatten.last
        end
      end
    end
    education_list << current_entry if current_entry
    
    # If no university keyword found, but we have text, build a fallback entry
    if education_list.empty? && lines.size > 0
      education_list << {
        'institution' => lines[0],
        'degree' => lines[1..2]&.join(", ") || "Degree details unspecified",
        'year' => lines.join(" ").scan(/\b(?:19|20)\d{2}\b/).last
      }
    end

    education_list
  end

  def parse_experience(lines)
    return [] if lines.nil? || lines.empty?
    
    experiences = []
    current_exp = nil

    lines.each do |line|
      # If line contains common job description date ranges or company indicators
      # Let's consider lines that contain months or years with dashes as job boundaries
      is_new_job = line =~ /\b(19|20)\d{2}\s*[-–—]\s*(present|current|aktif|\b(19|20)\d{2}\b)/i ||
                   line =~ /(developer|engineer|manager|analyst|designer|intern|stajyer|uzman|yönetici|lead|architect)\b/i && line.size < 50 && current_exp.nil?

      if is_new_job && line.size < 80
        experiences << current_exp if current_exp
        current_exp = {
          'role' => line,
          'company' => 'Company Details Unspecified',
          'duration' => '',
          'description' => []
        }
        # Try to extract dates from this line if present
        if line =~ /\b(19|20)\d{2}\s*[-–—]\s*(present|current|aktif|\b(19|20)\d{2}\b)/i
          current_exp['duration'] = line.scan(/\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)?\s*(?:19|20)\d{2}\s*[-–—]\s*(?:present|current|aktif|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)?\s*(?:19|20)\d{2})/i).first
        end
      elsif current_exp
        # If the line contains company keywords or typical indicators, set company
        if current_exp['company'] == 'Company Details Unspecified' && line =~ /(inc|ltd|gmbh|co|corp|holding|teknoloji|tech|a\.ş|ştd)/i
          current_exp['company'] = line
        elsif line.start_with?('-') || line.start_with?('*') || line.start_with?('•')
          current_exp['description'] << line.gsub(/^[-*•]\s*/, '').strip
        else
          # Check for duration if it wasn't on the title line
          if current_exp['duration'].empty? && line =~ /\b(19|20)\d{2}\s*[-–—]\s*(present|current|aktif|\b(19|20)\d{2}\b)/i
            current_exp['duration'] = line
          else
            # Otherwise append to description
            current_exp['description'] << line
          end
        end
      end
    end
    experiences << current_exp if current_exp

    # Fix experience fields (e.g. if company was never specified but we have descriptions)
    experiences.each do |exp|
      exp['description'] = exp['description'].join(" ") if exp['description'].is_a?(Array)
    end

    # Fallback if parsing failed but we had lines
    if experiences.empty? && lines.size > 0
      experiences << {
        'role' => 'Professional Position',
        'company' => lines[0],
        'duration' => lines.join(" ").scan(/\b(19|20)\d{2}\s*[-–—]\s*(present|current|aktif|\b(19|20)\d{2}\b)/i).first || 'Date not specified',
        'description' => lines[1..-1].join(" ")
      }
    end

    experiences
  end

  def parse_projects(lines)
    return [] if lines.nil? || lines.empty?
    
    projects = []
    current_proj = nil

    lines.each do |line|
      # Look for project name patterns (short lines, capitalized)
      is_new_proj = line.size < 50 && line =~ /^[A-Z0-9]/ && (line =~ /(system|application|platform|website|app|tool|library|framework|api|engine|dashboard|portfol|mind|iq|engine)/i || projects.empty? && current_proj.nil?)
      
      if is_new_proj
        projects << current_proj if current_proj
        current_proj = {
          'title' => line,
          'description' => []
        }
      elsif current_proj
        current_proj['description'] << line.gsub(/^[-*•]\s*/, '').strip
      end
    end
    projects << current_proj if current_proj

    projects.each do |proj|
      proj['description'] = proj['description'].join(" ") if proj['description'].is_a?(Array)
    end

    # Fallback if parsing failed but we have lines
    if projects.empty? && lines.size > 0
      projects << {
        'title' => lines[0],
        'description' => lines[1..-1].join(" ")
      }
    end

    projects
  end

  def parse_skills(section_lines, full_text)
    # The skills section can list skills directly, but it is much more comprehensive to scan
    # the entire text for known technical skills. We will let the SkillAnalyzerService do that scanning,
    # but we will extract skills from the "skills section" explicitly as a starting point.
    
    return [] if section_lines.nil? || section_lines.empty?
    
    skills = []
    section_lines.each do |line|
      # Split by comma, slash, semicolon, or bullet point
      parts = line.split(/[,;\/|•]|\s{2,}/)
      parts.each do |part|
        clean = part.strip.gsub(/^[-*•]\s*/, '')
        skills << clean if clean.size > 1 && clean.size < 40 && !(clean =~ /experience|level|proficien/i)
      end
    end
    skills.uniq
  end

  def extract_profile_photo
    ext = File.extname(@filename).downcase
    case ext
    when '.docx'
      extract_docx_photo
    when '.pdf'
      extract_pdf_photo
    else
      nil
    end
  rescue => e
    warn "Profile photo extraction failed: #{e.message}"
    nil
  end

  def extract_docx_photo
    Zip::File.open(@file_path) do |zip_file|
      media_files = zip_file.select { |entry| entry.name =~ /^word\/media\/image\d+\.(png|jpg|jpeg|gif)$/i }
      return nil if media_files.empty?
      
      largest_entry = media_files.max_by { |entry| entry.size }
      return nil if largest_entry.size < 3000 
      
      image_data = largest_entry.get_input_stream.read
      mime_type = case File.extname(largest_entry.name).downcase
                  when '.png' then 'image/png'
                  when '.gif' then 'image/gif'
                  else 'image/jpeg'
                  end
                  
      "data:#{mime_type};base64,#{Base64.strict_encode64(image_data)}"
    end
  rescue => e
    warn "DOCX image extraction failed: #{e.message}"
    nil
  end

  def extract_pdf_photo
    reader = PDF::Reader.new(@file_path)
    images = []
    
    reader.objects.each do |id, obj|
      next unless obj.respond_to?(:hash) && obj.respond_to?(:data)
      
      dict = obj.hash
      next unless dict.is_a?(Hash) && dict[:Subtype] == :Image
      
      width = dict[:Width] || 0
      height = dict[:Height] || 0
      next if width < 80 || height < 80
      
      filter = dict[:Filter]
      filters = filter.is_a?(Array) ? filter : [filter]
      
      if filters.include?(:DCTDecode)
        images << {
          data: obj.data,
          mime: 'image/jpeg',
          size: obj.data.bytesize
        }
      end
    end
    
    return nil if images.empty?
    
    largest_img = images.max_by { |img| img[:size] }
    "data:#{largest_img[:mime]};base64,#{Base64.strict_encode64(largest_img[:data])}"
  rescue => e
    warn "PDF image extraction failed: #{e.message}"
    nil
  end
end
