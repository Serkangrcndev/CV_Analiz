class DashboardStatisticsService
  def self.stats
    records = AnalysisRecord.all
    return empty_stats if records.empty?

    scores = records.map { |r| r.scores['general'] || 0 }
    avg_score = (scores.sum.to_f / scores.size).round(1)

    # Count skill frequencies
    skill_counts = Hash.new(0)
    records.each do |record|
      record.skills.each do |skill|
        skill_counts[skill] += 1
      end
    end
    top_skills = skill_counts.sort_by { |_, count| count }.reverse.first(6).to_h

    # Focus area distribution
    focus_counts = Hash.new(0)
    records.each do |record|
      # Extract primary focus from first recommendation or default
      focus = record.career_recommendations.first&.[]('role') || 'Software Engineering'
      focus_counts[focus] += 1
    end

    # Score brackets distribution
    brackets = {
      'Excellent (90+)' => 0,
      'Good (80-89)' => 0,
      'Average (70-79)' => 0,
      'Needs Improvement (<70)' => 0
    }
    scores.each do |s|
      if s >= 90
        brackets['Excellent (90+)'] += 1
      elsif s >= 80
        brackets['Good (80-89)'] += 1
      elsif s >= 70
        brackets['Average (70-79)'] += 1
      else
        brackets['Needs Improvement (<70)'] += 1
      end
    end

    {
      'total_analyses' => records.size,
      'average_score' => avg_score,
      'top_skills' => top_skills,
      'focus_distribution' => focus_counts,
      'score_distribution' => brackets,
      'records' => records.first(10) # last 10 records for history listing
    }
  end

  private

  def self.empty_stats
    {
      'total_analyses' => 0,
      'average_score' => 0.0,
      'top_skills' => {},
      'focus_distribution' => {},
      'score_distribution' => {
        'Excellent (90+)' => 0,
        'Good (80-89)' => 0,
        'Average (70-79)' => 0,
        'Needs Improvement (<70)' => 0
      },
      'records' => []
    }
  end
end
