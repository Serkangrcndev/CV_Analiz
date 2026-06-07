require 'spec_helper'

RSpec.describe CVParserService do
  let(:mock_text) do
    <<~TEXT
      John Doe
      john.doe@example.com | +1-555-555-0199 | github.com/johndoe | linkedin.com/in/johndoe

      EDUCATION
      Stanford University
      Bachelor of Science in Computer Science, GPA: 3.8/4.0 | 2018 - 2022

      EXPERIENCE
      Senior Backend Engineer
      Acme Tech Corp
      2022 - Present
      - Led a team of 4 engineers to develop microservices using Ruby on Rails and PostgreSQL.
      - Optimized database query response times by 35%, reducing server costs by $12k annually.
      - Implemented CI/CD pipelines with GitHub Actions and Docker.

      SKILLS
      Ruby, Rails, Postgres, Redis, AWS, Docker, Kubernetes, CI/CD, Jest, Git, REST API
    TEXT
  end

  let(:temp_file_path) { File.join(APP_ROOT, 'storage', 'uploads', 'test_resume.txt') }

  before do
    File.write(temp_file_path, mock_text)
  end

  after do
    FileUtils.rm_f(temp_file_path)
  end

  subject { described_class.new(temp_file_path, 'test_resume.txt') }

  describe '#parse' do
    let(:result) { subject.parse }

    it 'extracts personal information details' do
      expect(result[:personal_info]['name']).to eq('John Doe')
      expect(result[:personal_info]['email']).to eq('john.doe@example.com')
      expect(result[:personal_info]['phone']).to eq('1-555-555-0199')
      expect(result[:personal_info]['linkedin']).to eq('johndoe')
      expect(result[:personal_info]['github']).to eq('johndoe')
    end

    it 'extracts education details' do
      expect(result[:education]).not_to be_empty
      edu = result[:education].first
      expect(edu['institution']).to include('Stanford University')
      expect(edu['degree']).to include('Bachelor of Science')
      expect(edu['year']).to eq('2022')
      expect(edu['gpa']).to eq('3.8')
    end

    it 'extracts work experience details' do
      expect(result[:work_experience]).not_to be_empty
      work = result[:work_experience].first
      expect(work['role']).to include('Senior Backend Engineer')
      expect(work['company']).to include('Acme Tech Corp')
    end
  end
end
