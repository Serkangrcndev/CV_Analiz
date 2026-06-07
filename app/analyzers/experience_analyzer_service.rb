class ExperienceAnalyzerService
  SENIORITY_KEYWORDS = {
    'Lead/Principal' => /(principal|director|head of|manager|chief|lead architect|müdür|yönetici)/i,
    'Senior' => /(senior|sr\.|yüksek|kıdemli|lead developer|lead engineer)/i,
    'Junior' => /(junior|jr\.|intern|stajyer|trainee|yeni mezun|assistant|asistan)/i
  }

  METRIC_KEYWORDS = [
    /increased/i, /decreased/i, /improved/i, /saved/i, /optimized/i, /reduced/i,
    /arttırdı/i, /geliştirdi/i, /düşürdü/i, /tasarruf/i, /optimize etti/i, /büyüttü/i
  ]

  LEADERSHIP_KEYWORDS = [
    /led\b/i, /managed/i, /supervised/i, /directed/i, /mentored/i, /coached/i,
    /hired/i, /coordinated/i, /liderlik/i, /yönetti/i, /koordine/i, /eğitti/i
  ]

  def initialize(work_experience_data, full_text)
    @experiences = work_experience_data || []
    @full_text = full_text || ""
  end

  def analyze
    total_years = calculate_total_years
    seniority = determine_seniority(total_years)
    has_leadership = check_leadership
    metrics = detect_metrics

    {
      'total_years' => total_years,
      'seniority' => seniority,
      'has_leadership' => has_leadership,
      'metrics_count' => metrics.size,
      'metric_sentences' => metrics
    }
  end

  private

  def calculate_total_years
    # Find all date spans in the duration fields or general text
    durations = @experiences.map { |exp| exp['duration'] }.reject(&:nil?).reject(&:empty?)
    
    # If no durations in experiences, search full text for year spans e.g., 2018 - 2022
    if durations.empty?
      durations = @full_text.scan(/\b(20\d{2})\s*[-–—]\s*(present|current|aktif|20\d{2})\b/i).map { |m| m.join(" - ") }
    end

    total_months = 0
    
    durations.each do |duration|
      # Parse year spans
      years = duration.scan(/\b(19|20)\d{2}\b/).flatten.map(&:to_i)
      if years.size == 2
        # E.g. 2018 - 2022
        total_months += (years[1] - years[0]) * 12
      elsif years.size == 1 && duration =~ /(present|current|aktif|şimdi)/i
        # E.g. 2020 - Present
        current_year = Time.now.year
        total_months += (current_year - years[0]) * 12
      end
    end

    years = (total_months / 12.0).round(1)
    # If years is 0 but they have experience entries, default to 1 year minimum per entry or 1 year total
    if years == 0 && !@experiences.empty?
      years = 1.0
    end
    years
  end

  def determine_seniority(years)
    # Check titles first
    titles = @experiences.map { |exp| exp['role'] }.compact.join(" ")
    
    SENIORITY_KEYWORDS.each do |level, regex|
      return level if titles =~ regex
    end

    # Fallback to years of experience
    if years >= 8
      'Lead/Principal'
    elsif years >= 5
      'Senior'
    elsif years >= 2
      'Mid-Level'
    else
      'Junior'
    end
  end

  def check_leadership
    descriptions = @experiences.map { |exp| exp['description'] }.compact.join(" ")
    titles = @experiences.map { |exp| exp['role'] }.compact.join(" ")
    combined = "#{titles} #{descriptions}"

    LEADERSHIP_KEYWORDS.any? { |kw| combined =~ kw }
  end

  def detect_metrics
    sentences = []
    
    # Split description into sentences to isolate where metrics are used
    descriptions = @experiences.map { |exp| exp['description'] }.compact.join(" ")
    return [] if descriptions.empty?

    raw_sentences = descriptions.split(/[.!?\n]/).map(&:strip).reject(&:empty?)
    
    raw_sentences.each do |sentence|
      # Look for numeric metrics like percentages, $, dollar values, numbers > 10
      has_number = sentence =~ /\b\d+(?:\.\d+)?\s*(?:%|percent|k|m|million|billion|usd|try|dollar|euro|tl)\b/i ||
                   sentence =~ /\b(?:increase|decrease|improve|reduce|save|optimize)s?\s*(?:by|of)?\s*\d+/i ||
                   sentence =~ /\b\d+\s*(?:users|clients|servers|requests|team members|hours|days|percent)/i
      
      has_verb = METRIC_KEYWORDS.any? { |kw| sentence =~ kw }

      if has_number && has_verb
        sentences << sentence
      end
    end

    sentences.uniq
  end
end
