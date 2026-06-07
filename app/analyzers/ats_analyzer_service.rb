class ATSAnalyzerService
  def initialize(parsed_data)
    @data = parsed_data
    @filename = parsed_data[:filename] || ""
    @text = parsed_data[:parsed_text] || ""
    @personal_info = parsed_data[:personal_info] || {}
    @education = parsed_data[:education] || []
    @experience = parsed_data[:work_experience] || []
    @skills = parsed_data[:skills] || []
  end

  def analyze
    warnings = []
    passes = []
    score = 100

    # 1. File Type check
    ext = File.extname(@filename).downcase
    if ['.pdf', '.docx'].include?(ext)
      passes << "Optimal file format detected (#{ext.upcase}). Highly compatible with modern ATS scanners."
    else
      score -= 15
      warnings << "Sub-optimal file format (#{ext.upcase || 'TXT'}). Standard ATS parses PDF or DOCX files more accurately."
    end

    # 2. Critical sections check
    if @education.empty?
      score -= 15
      warnings << "Education section was not explicitly identified. Ensure standard headers like 'Education' or 'Eğitim' are used."
    else
      passes << "Education section successfully identified."
    end

    if @experience.empty?
      score -= 20
      warnings << "Work Experience section was not identified. Recruiters and ATS prioritizes chronological work history."
    else
      passes << "Work Experience section successfully identified."
    end

    if @skills.empty?
      score -= 15
      warnings << "Skills section was not identified. Make sure skills are clearly listed under an explicit 'Skills' header."
    else
      passes << "Skills section successfully identified."
    end

    # 3. Essential contact links check
    if @personal_info['email'].nil? || @personal_info['email'].empty?
      score -= 10
      warnings << "Email address not found. This is a critical contact detail for outreach."
    else
      passes << "Contact email detected."
    end

    if @personal_info['linkedin'].nil? || @personal_info['linkedin'].empty?
      score -= 10
      warnings << "LinkedIn profile link is missing. 90%+ of recruiters verify LinkedIn profiles."
    else
      passes << "LinkedIn profile link detected."
    end

    if @personal_info['github'].nil? || @personal_info['github'].empty?
      score -= 5
      warnings << "GitHub profile link is missing. Highly recommended for technical engineering roles."
    else
      passes << "GitHub profile link detected."
    end

    # 4. Resume length / Word count
    word_count = @text.split.size
    if word_count < 150
      score -= 10
      warnings << "Resume length is too short (#{word_count} words). Expand on your role descriptions and skills."
    elsif word_count > 1500
      score -= 10
      warnings << "Resume is too lengthy (#{word_count} words). Condense it to a highly impactful 1-2 pages."
    else
      passes << "Optimal resume word count (#{word_count} words)."
    end

    # 5. Non-standard layout warning (e.g. graphics or parsing anomalies)
    # Detect if text contains strange character representations which happen during bad formatting conversion
    if @text.scan(/[■♦▲●✓✔◆➔➜]/).size > 15
      score -= 5
      warnings << "Excessive special symbols/icons detected. Some ATS parsers struggle with non-standard unicode characters."
    end

    # Ensure score bounds
    score = [score, 30].max

    {
      'score' => score,
      'warnings' => warnings,
      'passes' => passes
    }
  end
end
