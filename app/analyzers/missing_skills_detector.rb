class MissingSkillsDetector
  # Standard core requirement sets for target careers
  PROFILE_REQUIREMENTS = {
    'Backend Developer' => ['Docker', 'Kubernetes', 'CI/CD', 'Unit Testing', 'Microservices', 'PostgreSQL', 'Redis', 'REST API', 'SOLID', 'System Design'],
    'Frontend Developer' => ['TypeScript', 'Next.js', 'Tailwind', 'Sass', 'Webpack', 'Redux', 'Unit Testing', 'Svelte', 'CSS', 'JavaScript'],
    'DevOps Engineer' => ['Kubernetes', 'Terraform', 'CI/CD', 'Ansible', 'AWS', 'Grafana', 'Prometheus', 'Nginx', 'Docker Compose', 'Linux'],
    'Data Scientist / Analyst' => ['Python', 'Pandas', 'NumPy', 'Machine Learning', 'TensorFlow', 'PostgreSQL', 'Tableau', 'PowerBI', 'Git', 'SQL'],
    'Full Stack Developer' => ['React', 'Node.js', 'PostgreSQL', 'Docker', 'Tailwind', 'REST API', 'Unit Testing', 'CI/CD', 'Git', 'Redis'],
    'AI / Machine Learning Engineer' => ['Python', 'PyTorch', 'TensorFlow', 'Machine Learning', 'Pandas', 'NumPy', 'Git', 'scikit-learn', 'Hugging Face', 'LLMs'],
    'Mobile App Developer' => ['Swift', 'SwiftUI', 'Kotlin', 'Flutter', 'React Native', 'Android SDK', 'Git', 'REST API', 'SQLite', 'UI/UX']
  }

  def initialize(detected_skills)
    @skills = detected_skills.map(&:downcase) || []
  end

  def detect
    gaps = {}

    PROFILE_REQUIREMENTS.each do |role, requirements|
      missing = requirements.select do |req|
        !@skills.include?(req.downcase)
      end
      # Take up to 5 key gaps
      gaps[role] = missing.first(5)
    end

    gaps
  end
end
