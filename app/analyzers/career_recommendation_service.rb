class CareerRecommendationService
  CAREER_PROFILES = {
    'Backend Developer' => {
      skills: ['Ruby', 'Ruby on Rails', 'Rails', 'Sinatra', 'Python', 'Django', 'Flask', 'FastAPI', 'Node.js', 'Express', 'Go', 'Golang', 'Java', 'Spring Boot', 'C#', '.NET', 'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'REST API', 'GraphQL', 'Microservices', 'Docker', 'OOP', 'SOLID'],
      description: 'Focuses on server-side logic, database management, and building high-performance API architectures.'
    },
    'Frontend Developer' => {
      skills: ['HTML', 'CSS', 'JavaScript', 'TypeScript', 'React', 'Vue', 'Angular', 'Svelte', 'Next.js', 'Tailwind', 'Bootstrap', 'Redux', 'Vite', 'Webpack', 'Sass', 'REST API'],
      description: 'Focuses on designing visually stunning user interfaces, user experiences, and single page web applications.'
    },
    'DevOps Engineer' => {
      skills: ['AWS', 'Docker', 'Kubernetes', 'CI/CD', 'GitHub Actions', 'Jenkins', 'Terraform', 'Ansible', 'GCP', 'Azure', 'Linux', 'Nginx', 'Docker Compose', 'Prometheus', 'Grafana', 'Git'],
      description: 'Bridges the gap between development and operations by maintaining infrastructure, CI/CD pipelines, and cloud scalability.'
    },
    'Data Scientist / Analyst' => {
      skills: ['Python', 'Django', 'FastAPI', 'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'Linux', 'Docker', 'Git', 'Machine Learning', 'TensorFlow', 'Pandas', 'NumPy', 'Tableau', 'PowerBI'],
      description: 'Analyzes structured/unstructured datasets, builds predictive models, and translates metrics into strategic business insights.'
    },
    'Full Stack Developer' => {
      skills: ['HTML', 'CSS', 'JavaScript', 'TypeScript', 'React', 'Ruby', 'Ruby on Rails', 'Rails', 'Node.js', 'PostgreSQL', 'MySQL', 'Redis', 'REST API', 'Git', 'Docker', 'Tailwind'],
      description: 'Handles both client-side and server-side components, building complete end-to-end web applications.'
    },
    'AI / Machine Learning Engineer' => {
      skills: ['Python', 'PyTorch', 'TensorFlow', 'Machine Learning', 'Pandas', 'NumPy', 'Keras', 'scikit-learn', 'Hugging Face', 'LangChain', 'OpenAI API', 'LLMs', 'NLP', 'Computer Vision', 'Spark', 'Kafka', 'Git'],
      description: 'Designs and deploys artificial intelligence systems, neural networks, machine learning models, and complex data pipeline frameworks.'
    },
    'Mobile App Developer' => {
      skills: ['Swift', 'SwiftUI', 'Objective-C', 'Kotlin', 'Android SDK', 'Flutter', 'React Native', 'Xamarin', 'iOS', 'Android', 'REST API', 'Git', 'SQLite'],
      description: 'Builds beautiful, responsive native and cross-platform applications for mobile devices.'
    }
  }

  def initialize(detected_skills)
    @skills = detected_skills.map(&:downcase) || []
  end

  def recommend
    recommendations = []

    CAREER_PROFILES.each do |role, profile|
      profile_skills = profile[:skills].map(&:downcase)
      intersection = @skills & profile_skills
      
      # Calculate matching score (percentage of matching skills)
      match_pct = if profile_skills.empty?
                    0
                  else
                    ((intersection.size.to_f / [profile_skills.size, 10].min) * 100).round(0)
                  end
      
      # Cap percentage at 100
      match_pct = [match_pct, 100].min

      # Determine top matched skills for this profile to list in UI
      matched_keywords = profile[:skills].select { |s| @skills.include?(s.downcase) }

      recommendations << {
        'role' => role,
        'match_percentage' => match_pct,
        'description' => profile[:description],
        'matched_skills' => matched_keywords
      }
    end

    # Sort by match percentage descending and return all profiles
    recommendations.sort_by { |rec| rec['match_percentage'] }.reverse
  end
end
