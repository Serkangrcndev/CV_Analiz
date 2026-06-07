class AnalysisRecord
  DB_FILE = File.join(APP_ROOT, 'storage', 'analyses.json')

  attr_accessor :id, :filename, :parsed_text, :personal_info, :education, 
                :work_experience, :skills, :projects, :scores, :highlights, 
                :career_recommendations, :missing_skills, :guide, :roadmap, 
                :interview_prep, :created_at

  def initialize(attrs = {})
    @id = attrs['id'] || SecureRandom.uuid
    @filename = attrs['filename']
    @parsed_text = attrs['parsed_text'] || ""
    @personal_info = attrs['personal_info'] || {}
    @education = attrs['education'] || []
    @work_experience = attrs['work_experience'] || []
    @skills = attrs['skills'] || []
    @projects = attrs['projects'] || []
    @scores = attrs['scores'] || {}
    @highlights = attrs['highlights'] || { 'strengths' => [], 'weaknesses' => [], 'suggestions' => [] }
    @career_recommendations = attrs['career_recommendations'] || []
    @missing_skills = attrs['missing_skills'] || {}
    @guide = attrs['guide'] || {}
    @roadmap = attrs['roadmap'] || []
    @interview_prep = attrs['interview_prep'] || []
    @created_at = attrs['created_at'] || Time.now.iso8601
  end

  def self.all
    return [] unless File.exist?(DB_FILE)
    begin
      data = JSON.parse(File.read(DB_FILE))
      data.map { |attrs| new(attrs) }.sort_by { |r| r.created_at }.reverse
    rescue => e
      warn "Failed to read database: #{e.message}"
      []
    end
  end

  def self.find(id)
    all.find { |record| record.id == id }
  end

  def self.create(attrs = {})
    record = new(attrs)
    record.save
    record
  end

  def self.delete(id)
    records = all.reject { |r| r.id == id }
    write_all(records)
    true
  end

  def save
    records = self.class.all
    existing_index = records.index { |r| r.id == @id }
    if existing_index
      records[existing_index] = self
    else
      records.unshift(self) # Newest first
    end
    self.class.write_all(records)
    self
  end

  def to_h
    {
      'id' => @id,
      'filename' => @filename,
      'parsed_text' => @parsed_text,
      'personal_info' => @personal_info,
      'education' => @education,
      'work_experience' => @work_experience,
      'skills' => @skills,
      'projects' => @projects,
      'scores' => @scores,
      'highlights' => @highlights,
      'career_recommendations' => @career_recommendations,
      'missing_skills' => @missing_skills,
      'guide' => @guide,
      'roadmap' => @roadmap,
      'interview_prep' => @interview_prep,
      'created_at' => @created_at
    }
  end

  private

  def self.write_all(records)
    File.write(DB_FILE, JSON.pretty_generate(records.map(&:to_h)))
  end
end
