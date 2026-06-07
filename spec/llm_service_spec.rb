require 'spec_helper'

RSpec.describe LLMService do
  let(:cv_text) { "Jane Doe. Ruby on Rails developer with Docker and Postgres experience." }

  describe '.active_model' do
    it 'returns the active model from settings service' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      expect(described_class.active_model).to eq('grok')
    end
  end

  describe '.configured?' do
    it 'returns false if settings service has no keys' do
      allow(SettingsService).to receive(:active_model).and_return('local')
      allow(SettingsService).to receive(:grok_key).and_return(nil)
      expect(described_class.configured?).to be false
    end

    it 'returns true if settings service has grok key configured' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      allow(SettingsService).to receive(:grok_key).and_return('mock-key')
      expect(described_class.configured?).to be true
    end
  end

  describe '.chat_response' do
    it 'routes call_grok if grok key is active' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      allow(SettingsService).to receive(:grok_key).and_return('mock-key')
      allow(described_class).to receive(:call_grok).and_return("AI response")
      res = described_class.chat_response(cv_text, "Hello", [], 'en')
      expect(res).to eq("AI response")
    end
  end

  describe '.evaluate_interview_answer' do
    it 'returns evaluation json if active' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      allow(SettingsService).to receive(:grok_key).and_return('mock-key')
      mock_json = { "score" => 90, "strengths" => ["Great"], "gaps" => ["None"], "refined_answer" => "Polished" }
      allow(described_class).to receive(:call_grok).and_return(mock_json)
      res = described_class.evaluate_interview_answer("Q?", "My answer", cv_text, 'en')
      expect(res['score']).to eq(90)
    end
  end

  describe '.align_job' do
    it 'returns match analysis if active' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      allow(SettingsService).to receive(:grok_key).and_return('mock-key')
      mock_json = { "score" => 85, "matched_keywords" => ["Rails"], "missing_keywords" => ["CI/CD"], "tailoring_suggestions" => ["Tweak summary"] }
      allow(described_class).to receive(:call_grok).and_return(mock_json)
      res = described_class.align_job(cv_text, "Wanted Rails developer with CI/CD", 'en')
      expect(res['score']).to eq(85)
    end
  end

  describe '.parse_cv_text' do
    it 'returns structured parsed resume json' do
      allow(SettingsService).to receive(:active_model).and_return('grok')
      allow(SettingsService).to receive(:grok_key).and_return('mock-key')
      mock_json = {
        "personal_info" => { "name" => "Jane" },
        "education" => [],
        "work_experience" => [],
        "projects" => [],
        "skills" => ["Ruby"]
      }
      allow(described_class).to receive(:call_grok).and_return(mock_json)
      res = described_class.parse_cv_text("Jane. Skills: Ruby")
      expect(res['personal_info']['name']).to eq("Jane")
      expect(res['skills']).to include("Ruby")
    end
  end
end
