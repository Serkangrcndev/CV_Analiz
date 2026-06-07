class SkillAnalyzerService
  DICTIONARY = {
    'Frontend' => [
      'HTML', 'CSS', 'JavaScript', 'TypeScript', 'React', 'Vue', 'Angular', 
      'Svelte', 'Next.js', 'Nuxt', 'Tailwind', 'Bootstrap', 'jQuery', 'Webpack', 
      'Vite', 'Redux', 'Sass', 'Less', 'WebSockets', 'GraphQL Client'
    ],
    'Backend' => [
      'Ruby', 'Ruby on Rails', 'Rails', 'Sinatra', 'Python', 'Django', 'Flask', 
      'FastAPI', 'Node.js', 'Express', 'Go', 'Golang', 'Java', 'Spring Boot', 
      'Spring', 'C#', '.NET', 'PHP', 'Laravel', 'Elixir', 'Phoenix', 'Rust', 'Scala'
    ],
    'DevOps & Cloud' => [
      'AWS', 'Docker', 'Kubernetes', 'CI/CD', 'GitHub Actions', 'Jenkins', 
      'Terraform', 'Ansible', 'GCP', 'Azure', 'Linux', 'Nginx', 'Docker Compose', 
      'Kubernetes Cluster', 'Prometheus', 'Grafana', 'Serverless', 'Vagrant',
      'Helm', 'ArgoCD', 'GitLab CI'
    ],
    'Databases & Caching' => [
      'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'SQLite', 'Elasticsearch', 
      'Oracle', 'SQL Server', 'Cassandra', 'Firebase', 'DynamoDB', 'Neo4j', 
      'MariaDB', 'Memcached'
    ],
    'Testing & QA' => [
      'RSpec', 'Jest', 'PyTest', 'JUnit', 'Selenium', 'Cypress', 'Mocha', 
      'Minitest', 'Unit Testing', 'Integration Testing', 'TDD', 'BDD'
    ],
    'Methodologies & Concepts' => [
      'Agile', 'Scrum', 'Kanban', 'REST API', 'GraphQL', 'Microservices', 
      'OOP', 'SOLID', 'Clean Code', 'MVC', 'Git', 'System Design', 'OAuth', 
      'JWT', 'Server-Side Rendering', 'Design Patterns'
    ],
    'AI & Data Science' => [
      'Python', 'PyTorch', 'TensorFlow', 'Pandas', 'NumPy', 'Keras', 'scikit-learn',
      'Hugging Face', 'LangChain', 'OpenAI API', 'LLMs', 'NLP', 'Computer Vision',
      'Spark', 'Kafka', 'Hadoop', 'Snowflake', 'Databricks', 'Machine Learning'
    ],
    'Mobile Development' => [
      'Swift', 'SwiftUI', 'Objective-C', 'Kotlin', 'Android SDK', 'Flutter',
      'React Native', 'Xamarin', 'iOS', 'Android'
    ]
  }

  def initialize(text, manually_extracted = [])
    @text = text || ""
    @manually_extracted = manually_extracted || []
  end

  def analyze
    detected = {}
    flat_detected = []

    DICTIONARY.each do |category, skills|
      detected[category] = []
      skills.each do |skill|
        # Match with word boundaries to prevent substring matching
        # e.g., "Go" matches "Go" but not "Google" or "going".
        # Handle special characters in skills like C++, C#, .NET, Next.js
        escaped_skill = Regexp.escape(skill)
        pattern = if skill.length <= 2
                    /\b#{escaped_skill}\b/i
                  elsif skill =~ /^[a-zA-Z]/
                    /\b#{escaped_skill}\b/i
                  else
                    /#{escaped_skill}/i
                  end

        if @text =~ pattern || @manually_extracted.any? { |s| s.downcase == skill.downcase }
          detected[category] << skill
          flat_detected << skill
        end
      end
    end

    # Clean up empty categories or ensure all are present
    flat_detected = flat_detected.uniq
    primary_focus = determine_primary_focus(detected)

    {
      'detected_skills' => flat_detected,
      'categorized' => detected,
      'primary_focus' => primary_focus
    }
  end

  private

  def determine_primary_focus(categorized)
    max_count = 0
    focus = 'Full Stack Development'

    categorized.each do |category, skills|
      if skills.size > max_count
        max_count = skills.size
        focus = case category
                when 'DevOps & Cloud' then 'DevOps & Infrastructure'
                when 'Databases & Caching' then 'Database Engineering'
                when 'Testing & QA' then 'QA & Testing Engineering'
                when 'Methodologies & Concepts' then 'Software Engineering Practice'
                else category
                end
      end
    end

    max_count > 0 ? focus : 'General Software Engineering'
  end
end
