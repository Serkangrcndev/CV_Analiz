require 'spec_helper'

RSpec.describe ResumeScoringService do
  let(:parsed_data) do
    {
      filename: 'resume.txt',
      parsed_text: 'Ruby on Rails and Docker expert. Senior Engineer. Optimized load times by 20%.',
      personal_info: {
        'name' => 'Jane Smith',
        'email' => 'jane.smith@example.com',
        'linkedin' => 'janesmith',
        'github' => 'janesmith'
      },
      education: [
        {
          'institution' => 'MIT',
          'degree' => 'BSc Computer Science',
          'year' => '2016'
        }
      ],
      work_experience: [
        {
          'role' => 'Senior Backend Engineer',
          'company' => 'Stripe',
          'duration' => '2018 - 2023',
          'description' => 'Developed APIs using Ruby and Rails. Optimized responses by 20%. Led team of 3.'
        }
      ],
      skills: ['Ruby', 'Rails', 'Docker', 'PostgreSQL', 'Git'],
      projects: [
        {
          'title' => 'Personal Portfolio',
          'description' => 'Web application built in React and Rails.'
        }
      ]
    }
  end

  subject { described_class.new(parsed_data) }

  describe '#score_and_save' do
    let!(:record) { subject.score_and_save }

    after do
      AnalysisRecord.delete(record.id)
    end

    it 'generates a valid analysis record with scores' do
      expect(record).to be_a(AnalysisRecord)
      expect(record.scores['general']).to be_between(30, 100)
      expect(record.scores['ats']).to be_between(30, 100)
      expect(record.scores['tech']).to be_between(30, 100)
      expect(record.scores['presentation']).to be_between(30, 100)
      expect(record.scores['employability']).to be_between(30, 100)
    end

    it 'generates highlights with strengths, weaknesses, and suggestions' do
      expect(record.highlights['strengths']).not_to be_empty
      expect(record.highlights['suggestions']).not_to be_empty
    end

    it 'recommends career paths matching skills' do
      expect(record.career_recommendations).not_to be_empty
      primary_role = record.career_recommendations.first['role']
      expect(['Backend Developer', 'Full Stack Developer', 'DevOps Engineer']).to include(primary_role)
    end
  end
end
