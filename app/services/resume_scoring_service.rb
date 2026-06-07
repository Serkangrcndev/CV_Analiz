class ResumeScoringService
  def initialize(parsed_data)
    @parsed_data = parsed_data
    @text = parsed_data[:parsed_text] || ""
    @personal_info = parsed_data[:personal_info] || {}
    @education = parsed_data[:education] || []
    @experience = parsed_data[:work_experience] || []
    @skills_list = parsed_data[:skills] || []
    @projects = parsed_data[:projects] || []
  end

  def score_and_save
    # 1. Run individual analyzers
    ats_results = ATSAnalyzerService.new(@parsed_data).analyze
    
    skill_analyzer = SkillAnalyzerService.new(@text, @skills_list)
    skills_results = skill_analyzer.analyze
    
    experience_analyzer = ExperienceAnalyzerService.new(@experience, @text)
    exp_results = experience_analyzer.analyze
    
    career_recs = CareerRecommendationService.new(skills_results['detected_skills']).recommend
    missing_skills = MissingSkillsDetector.new(skills_results['detected_skills']).detect

    # 2. Calculate subscores
    ats_score = ats_results['score']
    
    # Technical Competence Score
    detected_skills_count = skills_results['detected_skills'].size
    tech_score = if detected_skills_count >= 15
                   100
                 elsif detected_skills_count >= 10
                   90
                 elsif detected_skills_count >= 6
                   80
                 elsif detected_skills_count >= 3
                   65
                 else
                   45
                 end
    # Professional Presentation Score
    pres_score = 100
    pres_score -= 10 if @personal_info['linkedin'].nil? || @personal_info['linkedin'].empty?
    pres_score -= 10 if @personal_info['github'].nil? || @personal_info['github'].empty?
    pres_score -= 10 if @education.empty?
    pres_score -= 10 if ats_results['warnings'].size > 3
    pres_score = [pres_score, 40].max

    # Employability / Experience Rating
    emp_score = 60
    # Add points for years of experience
    emp_score += [exp_results['total_years'] * 5, 25].min.to_i
    # Add points for quantified achievements
    emp_score += [exp_results['metrics_count'] * 4, 12].min.to_i
    # Leadership bonus
    emp_score += 8 if exp_results['has_leadership']
    # Project presence bonus
    emp_score += 5 if !@projects.empty?
    emp_score = [emp_score, 100].min

    # General Score (Weighted average)
    general_score = ((ats_score * 0.3) + (tech_score * 0.3) + (pres_score * 0.2) + (emp_score * 0.2)).round(0)

    # 3. Assemble Strengths, Weaknesses, and Suggestions
    highlights = generate_highlights(ats_results, skills_results, exp_results)

    # 4. Generate Write-up Templates & Guides
    guide = generate_guide(ats_results, skills_results, exp_results, career_recs, missing_skills)

    # 5. Resolve Career Intelligence: Roadmap & Interview Prep (LLM or Local Fallback)
    primary_role = career_recs.first&.[]('role') || 'Full Stack Developer'
    gaps = missing_skills[primary_role] || []
    
    # Try to guess language based on parsed text
    lang = (@text =~ /[ışğçöüİĞÇÖÜ]/) ? 'tr' : 'en'

    llm_data = nil
    if LLMService.configured?
      llm_data = LLMService.generate_analysis(@text, primary_role, skills_results['detected_skills'], gaps, lang)
    end

    roadmap = if llm_data && llm_data['roadmap']
                llm_data['roadmap']
              else
                generate_local_roadmap(primary_role, gaps, lang)
              end

    interview_prep = if llm_data && llm_data['interview_prep']
                       llm_data['interview_prep']
                     else
                       generate_local_interview_prep(primary_role, gaps, lang)
                     end

    # 6. Save to model database
    record = AnalysisRecord.create(
      'filename' => @parsed_data[:filename],
      'parsed_text' => @text,
      'personal_info' => @personal_info,
      'education' => @education,
      'work_experience' => @experience,
      'skills' => skills_results['detected_skills'],
      'projects' => @projects,
      'scores' => {
        'general' => general_score,
        'ats' => ats_score,
        'tech' => tech_score,
        'presentation' => pres_score,
        'employability' => emp_score
      },
      'highlights' => highlights,
      'career_recommendations' => career_recs,
      'missing_skills' => missing_skills,
      'guide' => guide,
      'roadmap' => roadmap,
      'interview_prep' => interview_prep
    )

    record
  end

  private

  def generate_highlights(ats, skills, exp)
    strengths = []
    weaknesses = []
    suggestions = []

    # Compile Strengths
    if skills['detected_skills'].size >= 8
      strengths << "Technical skills section is highly defined with rich industry technology keywords."
    end
    if !@education.empty?
      strengths << "Educational background is clearly documented with standard structures."
    end
    if !@projects.empty?
      strengths << "Project portfolio and hands-on experience are outlined effectively."
    end
    if exp['metrics_count'] > 0
      strengths << "Work history emphasizes strong quantitative accomplishments."
    end
    if exp['has_leadership']
      strengths << "Demonstrates clear leadership, team mentoring, or project coordination capabilities."
    end
    if strengths.empty?
      strengths << "CV has a readable layout layout that covers standard elements."
    end

    # Compile Weaknesses (Eksikler)
    if @personal_info['linkedin'].nil? || @personal_info['linkedin'].empty?
      weaknesses << "LinkedIn profile connection is missing."
    end
    if @personal_info['github'].nil? || @personal_info['github'].empty?
      weaknesses << "GitHub repository reference is missing."
    end
    if exp['metrics_count'] == 0
      weaknesses << "Lack of measurable performance metrics and metrics-driven achievements."
    end
    if @education.empty?
      weaknesses << "Academic history is missing or lacks standard section labeling."
    end
    if skills['detected_skills'].size < 5
      weaknesses << "Technical skill listing is sparse or contains insufficient technical terminology."
    end

    # Compile Suggestions (Öneriler)
    if @personal_info['linkedin'].nil? || @personal_info['github'].nil?
      suggestions << "Incorporate active LinkedIn and GitHub links in the contact header."
    end
    if exp['metrics_count'] == 0
      suggestions << "Quantify your achievements with figures: e.g., 'Optimized loading speed by 25%' or 'Managed a server cluster of 50 node instances'."
    end
    suggestions << "Categorize skills explicitly under subheadings (Frontend, Backend, Infrastructure) for recruiter legibility."
    if !@projects.empty? && exp['metrics_count'] < 2
      suggestions << "Integrate tech stacks explicitly into project details to highlight hands-on execution."
    end
    suggestions << "Study and align with critical missing technologies like Docker, CI/CD, and Cloud architectures."

    {
      'strengths' => strengths.uniq.first(4),
      'weaknesses' => weaknesses.uniq.first(4),
      'suggestions' => suggestions.uniq.first(4)
    }
  end

  def generate_guide(ats, skills, exp, career_recs, missing_skills)
    guide = {}
    primary_role = career_recs.first&.[]('role') || 'Full Stack Developer'

    # 1. Professional Summary Guide (Önsöz Kılavuzu)
    summary_templates = {
      'Backend Developer' => {
        'en' => "Results-driven Backend Developer with 3+ years of experience specializing in Rails API architectures, PostgreSQL database design, and Docker containerization. Proven track record of optimizing database response times by 35% and implementing robust OAuth authentication layers.",
        'tr' => "Rails API mimarileri, PostgreSQL veritabanı tasarımı ve Docker konteynerleştirme konularında 3+ yıl deneyimli, sonuç odaklı Backend Geliştirici. Veritabanı sorgu yanıt sürelerini %35 optimize etme ve güvenli OAuth kimlik doğrulama katmanları oluşturma konularında kanıtlanmış başarı."
      },
      'Frontend Developer' => {
        'en' => "Creative Frontend Developer with 3+ years of experience engineering responsive, high-performance web applications using React, TypeScript, and Redux. Dedicated to building seamless user experiences and optimizing Core Web Vitals score metrics by 25%.",
        'tr' => "React, TypeScript ve Redux kullanarak duyarlı, yüksek performanslı web uygulamaları geliştiren 3+ yıl deneyimli Kreatif Ön Yüz Geliştirici. Kusursuz kullanıcı deneyimleri oluşturmaya ve Core Web Vitals skor metriklerini %25 optimize etmeye odaklı."
      },
      'DevOps Engineer' => {
        'en' => "Infrastructure Engineer with 3+ years of experience automating server deployments, designing scalable AWS VPC networks, and managing containerized applications with Kubernetes. Expert in GitHub Actions CI/CD pipelines and IaC via Terraform.",
        'tr' => "Sunucu dağıtımlarını otomatikleştiren, ölçeklenebilir AWS VPC ağları tasarlayan ve Kubernetes ile konteynerli uygulamaları yöneten 3+ yıl deneyimli Altyapı ve DevOps Mühendisi. GitHub Actions CI/CD süreçleri ve Terraform ile IaC (Altyapı Kodu) uzmanı."
      },
      'Data Scientist / Analyst' => {
        'en' => "Analytical Data Scientist with a strong foundation in Python statistical modeling, SQL querying, and machine learning pipelines. Experienced in translating raw unstructured data into actionable dashboard insights and improving forecast accuracy by 18%.",
        'tr' => "Python istatistiksel modelleme, SQL sorgulama ve makine öğrenimi boru hatları konularında güçlü bir temele sahip Analitik Veri Bilimci. Ham, yapılandırılmamış verileri dashboard analizlerine dönüştürme ve tahmin doğruluğunu %18 artırma deneyimli."
      },
      'Full Stack Developer' => {
        'en' => "Versatile Full Stack Developer with 3+ years of experience building end-to-end web systems. Expert in Rails backend services combined with React client interfaces. Passionate about writing clean, DRY code and optimizing application architecture scales.",
        'tr' => "Uçtan uca web sistemleri geliştirme konusunda 3+ yıl deneyimli Çok Yönlü Full Stack Geliştirici. React istemci arayüzleri ile entegre Rails arka uç servisleri uzmanı. Temiz, DRY kod yazmaya ve uygulama mimari ölçeklerini optimize etmeye tutkulu."
      }
    }
    
    selected_summary = summary_templates[primary_role] || summary_templates['Full Stack Developer']
    
    guide['summary'] = {
      'title' => {
        'en' => "Professional Summary Section",
        'tr' => "Profesyonel Özet / Önsöz Bölümü"
      },
      'placement' => {
        'en' => "At the very top of your CV, directly below your contact information header.",
        'tr' => "Özgeçmişinizin en üst kısmında, iletişim bilgileri başlığınızın hemen altında."
      },
      'before' => {
        'en' => "[No professional summary present on your resume]",
        'tr' => "[Özgeçmişinizde özet önsöz paragrafı bulunamadı]"
      },
      'after' => selected_summary
    }

    # 2. Contact Section Guide (İletişim Bölümü Kılavuzu)
    if @personal_info['linkedin'].nil? || @personal_info['github'].nil?
      github_val = @personal_info['github'] || "github.com/yourusername"
      linkedin_val = @personal_info['linkedin'] || "linkedin.com/in/yourprofile"
      
      guide['contact'] = {
        'title' => {
          'en' => "Contact Header Links",
          'tr' => "İletişim Başlığı ve Sosyal Bağlantılar"
        },
        'placement' => {
          'en' => "In your primary contact header block, next to email and telephone details.",
          'tr' => "E-posta ve telefon bilgilerinizin hemen yanındaki ana iletişim bilgileri bloğunda."
        },
        'before' => {
          'en' => "John Doe | john.doe@email.com | +90 555 123 4567",
          'tr' => "Ahmet Yılmaz | ahmet.yilmaz@email.com | +90 555 123 4567"
        },
        'after' => {
          'en' => "John Doe | john.doe@email.com | +90 555 123 4567\nGitHub: #{github_val} | LinkedIn: #{linkedin_val}",
          'tr' => "Ahmet Yılmaz | ahmet.yilmaz@email.com | +90 555 123 4567\nGitHub: #{github_val} | LinkedIn: #{linkedin_val}"
        }
      }
    end

    # 3. Quantified Work Experience Guide (Sayısal Deneyim Kılavuzu)
    if exp['metrics_count'] == 0
      guide['metrics'] = {
        'title' => {
          'en' => "Quantified Impact Statements",
          'tr' => "Ölçülebilir Deneyim Maddeleri"
        },
        'placement' => {
          'en' => "Within your job description bullet points to highlight the business impact of your work.",
          'tr' => "Yaptığınız işin iş etkisini ve ölçeğini vurgulamak için iş tanımı maddelerinizin içinde."
        },
        'before' => {
          'en' => "- Responsible for writing backend APIs and optimizing database queries.",
          'tr' => "- Arka uç API'leri yazmaktan ve veritabanı sorgularını optimize etmekten sorumlu."
        },
        'after' => {
          'en' => "- Engineered server-side REST APIs using Rails and optimized queries, reducing database response times by 35% and supporting up to 10k requests/minute.",
          'tr' => "- Rails kullanarak sunucu tarafı REST API'leri geliştirdim ve sorguları optimize ederek veritabanı yanıt sürelerini %35 azalttım (dakikada 10 bin istek ölçeğinde)."
        }
      }
    end

    # 4. Project Details Guide (Proje Detayı Kılavuzu)
    target_skills = missing_skills[primary_role] || []
    if !target_skills.empty?
      sample_skills = target_skills.first(2).join(" & ")
      guide['projects'] = {
        'title' => {
          'en' => "Tech-Stack Integration in Projects",
          'tr' => "Proje Açıklamalarında Teknoloji Entegrasyonu"
        },
        'placement' => {
          'en' => "In your projects section description blocks to show practical execution with target skills.",
          'tr' => "Hedeflenen becerileri pratik olarak kullandığınızı göstermek için projelerinizin açıklama bloklarında."
        },
        'before' => {
          'en' => "- Built a task tracker application for managing remote team assignments.",
          'tr' => "- Uzaktan çalışan ekiplerin görevlerini yönetmek için bir iş takip uygulaması yaptım."
        },
        'after' => {
          'en' => "- Built a collaborative task tracker application integrating #{sample_skills}, containerized deployment models, and automated integration checks.",
          'tr' => "- #{sample_skills} entegrasyonu, konteynerli dağıtım modelleri ve otomatik entegrasyon kontrolleri içeren ortak bir iş takip uygulaması geliştirdim."
        }
      }
    end

    guide
  end

  def generate_local_roadmap(role, missing, lang)
    missing_list = missing.empty? ? ['Docker', 'CI/CD'] : missing
    
    if lang == 'tr'
      [
        {
          'stage' => '1. Ay: Temel Eğitimi',
          'objective' => "#{missing_list.first(2).join(' ve ')} teknolojilerinin temellerini öğrenmek.",
          'tasks' => [
            "#{missing_list.first} resmi dokümantasyonunu oku ve temel kurulumları yap.",
            "Basit pratik senaryolarla küçük konteyner denemeleri gerçekleştir.",
            "Öğrendiğin konseptlerle ilgili teknik makaleler veya blog yazıları oku."
          ]
        },
        {
          'stage' => '2. Ay: Proje Entegrasyonu',
          'objective' => "Öğrenilen becerileri gerçek projelere entegre ederek pratik tecrübe edinmek.",
          'tasks' => [
            "Mevcut projelerinden birine #{missing_list.first} entegrasyonu yap.",
            "#{missing_list[1] || 'Yeni kütüphaneler'} ile projeyi zenginleştir ve otomasyon testleri ekle.",
            "Hata giderme (debugging) süreçlerini yöneterek pratik tecrübe kazan."
          ]
        },
        {
          'stage' => '3. Ay: Dağıtım ve Bulut Ölçekleme',
          'objective' => "Uygulamayı ölçeklendirmek, test etmek ve bulut ortamına dağıtmak.",
          'tasks' => [
            "Projenin otomatik CI/CD hatlarını kur.",
            "Dağıtım (deployment) modellerini ve entegrasyon kanallarını canlı ortama hazırla.",
            "Performans optimizasyonları yaparak projeyi GitHub üzerinde açık kaynak olarak paylaş."
          ]
        }
      ]
    else
      [
        {
          'stage' => 'Month 1: Fundamentals',
          'objective' => "Master the basics of #{missing_list.first(2).join(' and ')}.",
          'tasks' => [
            "Study the official documentation for #{missing_list.first} and set up local environments.",
            "Build simple sandbox prototypes to understand core concepts.",
            "Follow basic tutorials and practice syntax/commands daily."
          ]
        },
        {
          'stage' => 'Month 2: Project Integration',
          'objective' => "Integrate target technologies into hands-on personal portfolio projects.",
          'tasks' => [
            "Refactor an existing project to incorporate #{missing_list.first}.",
            "Add #{missing_list[1] || 'modern testing models'} to expand features.",
            "Manage configuration issues and document debugging steps."
          ]
        },
        {
          'stage' => 'Month 3: Deployment & Delivery',
          'objective' => "Automate testing pipelines and deploy applications to production sandbox spaces.",
          'tasks' => [
            "Implement automated testing frameworks to secure code stability.",
            "Configure continuous integration and deployment hooks.",
            "Publish projects on GitHub with high-quality README guides for showcase."
          ]
        }
      ]
    end
  end

  def generate_local_interview_prep(role, missing, lang)
    missing_list = missing.empty? ? ['Docker', 'CI/CD'] : missing
    
    if lang == 'tr'
      [
        {
          'question' => "#{missing_list.first} teknolojisinin mimari yapısını ve sağladığı temel avantajları açıklayabilir misiniz?",
          'context' => "Adayın CV'sinde eksik olan #{missing_list.first} konusundaki teorik bilgi düzeyini ve kavrayışını ölçmek için sorulur.",
          'suggested_answer' => "Bu teknoloji, uygulamaların tüm bağımlılıkları ile birlikte izole bir şekilde paketlenmesini sağlar. 'Bir kez yaz, her yerde çalıştır' prensibiyle çalışarak ortamlar arası (lokal vs prod) uyumsuzlukları ortadan kaldırır. Konteyner yapısı, sanal makinelere göre çok daha hafif ve hızlı başlatılabilirdir."
        },
        {
          'question' => "Projelerinizde kod kalitesini korumak için nasıl bir test ve CI/CD akışı kurarsınız?",
          'context' => "Modern yazılım geliştirme süreçlerine ve otomasyon araçlarına olan aşinalığı ölçmek için sorulur.",
          'suggested_answer' => "Kod her commit edildiğinde otomatik olarak tetiklenen bir pipeline kurgularım. İlk aşamada statik kod analizi (linter) ve birim testler (unit tests) çalışır. Testler başarıyla tamamlanırsa kod derlenir, dockerize edilir ve staging ortamına otomatik olarak dağıtılır. Bu sayede hataları erken aşamada tespit edebilirim."
        },
        {
          'question' => "Geçmiş projelerinizde karşılaştığınız en büyük teknik zorluk neydi ve bunu nasıl çözdünüz?",
          'context' => "Problem çözme yaklaşımını, analitik düşünce yapısını ve kriz yönetim becerisini değerlendirmek için sorulur.",
          'suggested_answer' => "Örnek olarak: Bir veritabanı yavaşlığı probleminde yavaş çalışan sorguları log analizleri ile tespit ettim. İlgili tablolara doğru indeksleri ekleyerek ve n+1 sorgu problemlerini gidererek yanıt sürelerini %40 civarında düşürdüm. Bu süreçde veri tutarlılığını korumak için migration işlemlerini güvenli şekilde planladım."
        }
      ]
    else
      [
        {
          'question' => "Can you explain the architectural layout and key benefits of using #{missing_list.first}?",
          'context' => "Asked to evaluate theoretical understanding of #{missing_list.first} which is currently missing from your resume.",
          'suggested_answer' => "It enables packaging applications with all their dependencies into isolated containers. Unlike traditional virtual machines, containers share the host OS kernel, making them lightweight, rapid to start, and highly consistent across development and production environments."
        },
        {
          'question' => "How do you configure continuous integration (CI) and automated tests inside your projects?",
          'context' => "Evaluates experience with modern delivery workflows and automated code checks.",
          'suggested_answer' => "I configure triggers on repository commits. The pipeline first runs static analysis (linters) and unit test suites (e.g., Jest or RSpec). If those pass, the application compiles and builds a package or image, pushing it to staging. This ensures defects are caught immediately."
        },
        {
          'question' => "What was the most challenging database or API bottleneck you solved in a past project?",
          'context' => "Assesses problem-solving skills, scalability awareness, and troubleshooting methodologies.",
          'suggested_answer' => "In a past bottleneck, API response latencies rose due to slow database queries. I identified unindexed foreign keys and N+1 query patterns using profiling logs. By adding indexes and eager-loading database records, average latency dropped by 35% and throughput stabilized."
        }
      ]
    end
  end
end
