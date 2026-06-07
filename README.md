# CareerMind AI — AI-Powered Resume Intelligence Engine

CareerMind AI is a professional-grade, self-contained CV parsing, scoring, and career intelligence engine built using modern Ruby (Sinatra) and dynamic glassmorphism UI layouts. 

The application parses uploaded resumes (PDF, DOCX, and TXT), extracts structural content using NLP and pattern heuristics, calculates key scoring sub-metrics (ATS Compliance, Technical Skills, Presentation, and Employability), visualizes tech taxonomy on canvas charts, and performs automated career matching and skill-gap recommendations.

---

## Features

- **Multi-Format Document Parsing**: High-fidelity text extraction from PDF, DOCX, and TXT files using native Ruby engines (`pdf-reader` & `docx`).
- **ATS Compliance Scanner**: Flags structural warning signs, layout issues, missing contact nodes, and document lengths to match recruiter parsing engines.
- **Skill Taxonomy Mapping**: Maps mentions of over 100+ programming languages, frameworks, systems, and testing practices into categorized dashboard pill containers.
- **Quantitative Accomplishment Audits**: Scans job descriptions for leadership cues and metrics-driven business accomplishments (percentages, financials, scale).
- **AI Career Mapping & Gaps Analyzer**: Computes estimated fit percentages for 5 major career paths (Backend, Frontend, DevOps, Data Science, and Full Stack) and highlights the exact technologies missing from the resume.
- **Premium Glassmorphic Dashboard**: Dark-themed visuals featuring SVG/Canvas radar skill maps, circular gauge scores, loading progression step checklists, and historic report navigation.
- **Dynamic PDF Report Generation**: Generates high-fidelity printable PDF reports containing candidate scores, strengths, weaknesses, and actions using `prawn`.

---

## System Architecture

```
cv-intelligence-engine/
├── app/
│   ├── controllers/
│   │   └── dashboard_controller.rb       # Sinatra route controller
│   ├── services/
│   │   ├── cv_parser_service.rb          # File readers & regex separators
│   │   ├── resume_scoring_service.rb     # Core scoring compiler
│   │   ├── pdf_report_generator.rb       # Prawn PDF compiler
│   │   └── dashboard_statistics_service.rb # Historical statistics compiler
│   ├── analyzers/
│   │   ├── ats_analyzer_service.rb       # Format & layout validation
│   │   ├── skill_analyzer_service.rb     # Dictionary categorizer
│   │   ├── experience_analyzer_service.rb # Senority & metrics auditor
│   │   ├── career_recommendation_service.rb # Job profile matching
│   │   └── missing_skills_detector.rb    # Gap analysis evaluator
│   ├── models/
│   │   └── analysis_record.rb            # Local thread-safe JSON CRUD layer
│   ├── helpers/
│   │   └── application_helper.rb         # HTML rendering helpers
│   └── views/
│       ├── layout.erb                    # HTML5 base layout wrapper
│       ├── index.erb                     # Upload portal & charts view
│       └── dashboard.erb                 # Metrics dashboard view
├── config/
│   └── environment.rb                    # App bootstrapper
├── public/
│   ├── css/
│   │   └── styles.css                    # Premium glassmorphic styles
│   └── js/
│       ├── uploader.js                   # AJAX drop-zone & loading states
│       └── charts.js                     # SVG/Canvas radar and gauge rendering
├── storage/
│   ├── analyses.json                     # Database storage array
│   └── uploads/                          # Temporary parsing space
├── spec/
│   ├── spec_helper.rb                    # Test runner setup
│   ├── cv_parser_service_spec.rb         # Parser validations
│   └── resume_scoring_service_spec.rb    # Scoring validations
├── Gemfile                               # Dependency manifest
├── config.ru                             # Rack mount script
└── README.md                             # Documentation
```

---

## Installation & Setup

### Prerequisites

- **Ruby**: Version 3.0 or higher (Ruby 4.0+ recommended)
- **Bundler**: `gem install bundler`

### Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/career-mind-ai.git
   cd career-mind-ai
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   ```

3. **Run tests to verify**:
   ```bash
   bundle exec rspec
   ```

4. **Launch the application**:
   ```bash
   bundle exec rackup -p 4567
   # OR run using puma directly:
   bundle exec puma -p 4567
   ```

5. Open your web browser and navigate to `http://localhost:4567`.

---

## API Documentation

The Sinatra controller exposes the following HTTP endpoints:

### 1. View Homepage
- **URL**: `GET /`
- **Description**: Displays the dashboard analytics and uploader drop-zone.

### 2. Upload and Analyze Resume
- **URL**: `POST /analyze`
- **Payload**: `multipart/form-data` containing `cv` (file stream).
- **Response**: `application/json`
  ```json
  {
    "status": "success",
    "redirect_url": "/dashboard/c92d53bf-e3b8-4c12-9c1c-99c58ea7dfb3"
  }
  ```

### 3. View Report Dashboard
- **URL**: `GET /dashboard/:id`
- **Description**: Renders the glassmorphic analytics view for the specified report ID.

### 4. Download PDF Report
- **URL**: `GET /download/:id`
- **Description**: Streams the generated printable PDF report to the browser as an attachment.

### 5. Delete Report
- **URL**: `POST /delete/:id`
- **Description**: Deletes a report from the database and redirects back to the homepage.

---

## Example Usage

### Ruby Console Testing
You can parse a resume manually inside `irb` or a custom script:

```ruby
require_relative 'config/environment'

# 1. Extract text and segment
parser = CVParserService.new('storage/uploads/sample_resume.pdf', 'sample_resume.pdf')
parsed_data = parser.parse

# 2. Run scoring suite and save
scoring = ResumeScoringService.new(parsed_data)
record = scoring.score_and_save

puts "Report Generated for: #{record.personal_info['name']}"
puts "General Score: #{record.scores['general']}/100"
puts "ATS Score: #{record.scores['ats']}/100"
puts "Primary Fit: #{record.career_recommendations.first['role']}"
```

---

## Future Roadmap

1. **OAuth Integrations**: Add Google & LinkedIn sign-in for individual secure candidate portals.
2. **LLM Hybrid Scanners**: Toggle API models (e.g. Gemini Pro, Claude) for deep semantic analysis of complex bullet point descriptions.
3. **Interactive Career Coach**: Chat interface providing customized interview preparation questions based on detected missing skills.
4. **Job Board Listings**: Sync matched profiles to live remote developer openings using active job board API integrations.

---

## Contributing

1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.
