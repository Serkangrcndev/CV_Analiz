class DashboardController < Sinatra::Base
  helpers ApplicationHelper

  # Configure Sinatra settings
  configure do
    set :views, File.join(APP_ROOT, 'app', 'views')
    set :public_folder, File.join(APP_ROOT, 'public')
    enable :sessions
    set :session_secret, SecureRandom.hex(64)
  end

  # Language switcher endpoint
  get '/locale/:lang' do
    lang = params[:lang]
    if ['en', 'tr'].include?(lang)
      session[:locale] = lang
    end
    redirect request.referrer || '/'
  end

  # Homepage & Stats View
  get '/' do
    @stats = DashboardStatisticsService.stats
    @records = AnalysisRecord.all
    erb :index
  end

  # Handle CV Upload & Analyze via AJAX
  post '/analyze' do
    content_type :json

    if params[:cv].nil? || params[:cv][:tempfile].nil?
      status 400
      return { error: 'Please choose a file to upload.' }.to_json
    end

    file = params[:cv][:tempfile]
    filename = params[:cv][:filename]
    
    # Save upload temporarily
    temp_path = File.join(APP_ROOT, 'storage', 'uploads', "#{SecureRandom.hex(8)}_#{filename}")
    FileUtils.cp(file.path, temp_path)

    begin
      # 1. Parse CV
      parser = CVParserService.new(temp_path, filename)
      parsed_data = parser.parse

      # 2. Score and Save Report
      scoring_service = ResumeScoringService.new(parsed_data)
      record = scoring_service.score_and_save

      # Return redirect url for JS uploader transition
      { status: 'success', redirect_url: "/dashboard/#{record.id}" }.to_json
    rescue => e
      warn "Analysis failed: #{e.message}\n#{e.backtrace.join("\n")}"
      status 500
      { error: "Analysis failed: #{e.message}" }.to_json
    ensure
      # Clean up uploaded file
      FileUtils.rm_f(temp_path) if File.exist?(temp_path)
    end
  end

  # Detailed Analysis View
  get '/dashboard/:id' do
    @record = AnalysisRecord.find(params[:id])
    if @record.nil?
      session[:error] = "The requested analysis record was not found."
      redirect '/'
    end

    @stats = DashboardStatisticsService.stats
    @records = AnalysisRecord.all
    erb :dashboard
  end

  # PDF Report Generation & Download
  get '/download/:id' do
    record = AnalysisRecord.find(params[:id])
    if record.nil?
      status 404
      return "Report not found."
    end

    begin
      content_type 'application/pdf'
      # Set attachment header
      attachment_name = "#{record.personal_info['name'].gsub(/\s+/, '_')}_CareerMind_AI_Report.pdf"
      attachment attachment_name

      # Generate PDF
      generator = PDFReportGenerator.new(record)
      generator.generate
    rescue => e
      status 500
      "Failed to generate PDF: #{e.message}"
    end
  end

  # Delete Record Action
  post '/delete/:id' do
    AnalysisRecord.delete(params[:id])
    session[:success] = "Analysis record deleted successfully."
    redirect '/'
  end

  # Manual Profile Photo Upload Override
  post '/dashboard/:id/upload_avatar' do
    record = AnalysisRecord.find(params[:id])
    if record.nil?
      status 404
      return "Profile record not found."
    end

    if params[:avatar] && params[:avatar][:tempfile]
      file = params[:avatar][:tempfile]
      ext = File.extname(params[:avatar][:filename]).downcase
      
      if ['.png', '.jpg', '.jpeg', '.gif'].include?(ext)
        mime_type = case ext
                    when '.png' then 'image/png'
                    when '.gif' then 'image/gif'
                    else 'image/jpeg'
                    end
        binary_data = file.read
        base64_data = "data:#{mime_type};base64,#{Base64.strict_encode64(binary_data)}"
        
        # Update record personal info photo
        personal_info = record.personal_info || {}
        personal_info['photo'] = base64_data
        record.personal_info = personal_info
        
        # Save updated model
        record.save
        session[:success] = "Profile picture updated successfully."
      else
        session[:error] = "Invalid image format. Please upload JPG, PNG, or GIF."
      end
    end
    
    redirect "/dashboard/#{record.id}"
  end

  # Chatbot interaction AJAX route
  post '/dashboard/:id/chat' do
    content_type :json
    record = AnalysisRecord.find(params[:id])
    if record.nil?
      status 404
      return { error: 'Record not found' }.to_json
    end

    message = params[:message]
    if message.nil? || message.strip.empty?
      status 400
      return { error: 'Message cannot be empty' }.to_json
    end

    # Initialize chat history for this record in session
    session[:chats] ||= {}
    session[:chats][record.id] ||= []

    # Get language preference or default to candidate profile lang
    lang = session[:locale] || (record.parsed_text =~ /[ışğçöüİĞÇÖÜ]/ ? 'tr' : 'en')

    response_text = nil
    if LLMService.configured?
      response_text = LLMService.chat_response(record.parsed_text, message, session[:chats][record.id], lang)
    end

    # Fallback to local expert chat if LLM fails or is not set
    if response_text.nil? || response_text.empty?
      response_text = local_chat_fallback(record, message, lang)
    end

    # Append to history
    session[:chats][record.id] << { 'role' => 'user', 'content' => message }
    session[:chats][record.id] << { 'role' => 'assistant', 'content' => response_text }

    { response: response_text }.to_json
  end

  # Mock Interview Live Evaluation AJAX route
  post '/dashboard/:id/interview/evaluate' do
    content_type :json
    record = AnalysisRecord.find(params[:id])
    if record.nil?
      status 404
      return { error: 'Record not found' }.to_json
    end

    question = params[:question]
    answer = params[:answer]

    if question.nil? || answer.nil? || answer.strip.empty?
      status 400
      return { error: 'Invalid question or answer content' }.to_json
    end

    lang = session[:locale] || (record.parsed_text =~ /[ışğçöüİĞÇÖÜ]/ ? 'tr' : 'en')

    eval_results = nil
    if LLMService.configured?
      eval_results = LLMService.evaluate_interview_answer(question, answer, record.parsed_text, lang)
    end

    if eval_results.nil? || eval_results['score'].nil?
      eval_results = local_interview_fallback(question, answer, lang)
    end

    eval_results.to_json
  end

  # Target Job Description Matcher AJAX route
  post '/dashboard/:id/match_job' do
    content_type :json
    record = AnalysisRecord.find(params[:id])
    if record.nil?
      status 404
      return { error: 'Record not found' }.to_json
    end

    job_description = params[:job_description]
    if job_description.nil? || job_description.strip.empty?
      status 400
      return { error: 'Job description cannot be empty' }.to_json
    end

    lang = session[:locale] || (record.parsed_text =~ /[ışğçöüİĞÇÖÜ]/ ? 'tr' : 'en')

    match_results = nil
    if LLMService.configured?
      match_results = LLMService.align_job(record.parsed_text, job_description, lang)
    end

    if match_results.nil? || match_results['score'].nil?
      match_results = local_job_match_fallback(record, job_description, lang)
    end

    match_results.to_json
  end

  private

  def local_chat_fallback(record, message, lang)
    msg = message.downcase
    name = record.personal_info['name'] || 'Candidate'
    skills = record.skills.first(5).join(", ")
    
    if lang == 'tr'
      if msg =~ /merhaba|selam/
        "Merhaba #{name}! Ben offline moddaki CareerMind AI Asistanıyım. CV'nizdeki #{skills} gibi yetkinliklerinizi geliştirmek için ne yapabileceğimizi konuşabiliriz. Gelişmiş cevaplar için config/settings.json dosyasından Grok API anahtarı (grok_api_key) tanımlayabilirsiniz."
      elsif msg =~ /proje|öner/
        "Özgeçmişinizdeki #{skills} becerilerini sergilemek için şu projeyi geliştirebilirsiniz: 1. Uçtan uca veri senkronizasyonu sağlayan modern bir API paneli. Docker ve CI/CD süreçlerini de eklemeyi unutmayın!"
      elsif msg =~ /eksik|nasıl kapatırım|öğren/
        "Eksik becerilerinizi kapatmak için Yol Haritası (Tech Roadmap) sekmesini inceleyebilirsiniz. Orada 3 aylık adım adım bir gelişim planı hazırladım."
      else
        "CV'nizi inceledim. Offline modda olduğum için bu sorunuza detaylı yanıt veremiyorum. Lütfen config/settings.json dosyasından Grok API anahtarınızı (grok_api_key) girin ve sistemi yeniden başlatın!"
      end
    else
      if msg =~ /hello|hi|hey/
        "Hello #{name}! I'm the offline CareerMind AI Assistant. We can discuss how to enhance your skills like #{skills}. To unlock advanced real-time AI replies, configure a Grok API Key (grok_api_key) in config/settings.json."
      elsif msg =~ /project|suggest/
        "To showcase your #{skills} skills, here is a project suggestion: Build a unified dashboard that automates data pipelines, incorporating containerization (Docker) and deployment pipelines."
      elsif msg =~ /missing|learn|improve/
        "To acquire your missing skills, check out the 'Tech Roadmap' tab. I've prepared a step-by-step 3-month integration plan there."
      else
        "I analyzed your CV. Since I'm running offline, I cannot provide a custom response to this specific query. Please configure a Grok API key (grok_api_key) in config/settings.json and restart the system!"
      end
    end
  end

  def local_interview_fallback(question, answer, lang)
    len = answer.to_s.strip.size
    score = 40
    score += [len / 10, 45].min
    
    keywords = ['framework', 'api', 'database', 'docker', 'test', 'ci/cd', 'git', 'kod', 'veri', 'performans', 'optimize', 'scalability', 'mimar']
    match_count = keywords.count { |w| answer.downcase.include?(w) }
    score += [match_count * 5, 15].min
    
    score = [score - 20, 20].max if len < 20
    score = [score, 100].min
    
    if lang == 'tr'
      {
        'score' => score,
        'strengths' => [
          "Soruya doğrudan bir cevap vermeye çalıştınız.",
          "Temel kavramları ve iş akışını belirtmeniz olumlu."
        ],
        'gaps' => [
          "Cevabınızı teknik detaylarla ve sayısal başarı örnekleriyle (örn: %30 hızlanma sağladım) zenginleştirmelisiniz.",
          "Mimari bileşenler ve entegrasyon yöntemlerine daha fazla değinebilirsiniz."
        ],
        'refined_answer' => "Mülakatta bu soruya şu şekilde yanıt vermeniz daha profesyonel olacaktır: 'Belirttiğiniz senaryoda, altyapıyı mikroservis yapısında kurgulayıp, Docker konteynerleri ile izole ederek CI/CD süreçlerine entegre ederim. Hataları izlemek için entegrasyon testlerini her commit aşamasında otomatik çalıştırıp, performansı %30 seviyesinde optimize ederim.'"
      }
    else
      {
        'score' => score,
        'strengths' => [
          "You addressed the core question directly in your initial sentence.",
          "You highlighted the importance of workflow stability."
        ],
        'gaps' => [
          "Incorporate technical metrics (e.g., 'reducing query latency by 40%') to make your answer more concrete.",
          "Elaborate on the architectural layout and orchestration tools used."
        ],
        'refined_answer' => "A more impactful way to answer this in an interview would be: 'In this scenario, I design a containerized service model using Docker, running automated CI/CD checks for validation. By implementing active logging and query caching, we can scale the throughput to handle higher loads and reduce response times by 30%.'"
      }
    end
  end

  def local_job_match_fallback(record, job_desc, lang)
    desc = job_desc.downcase
    matched = []
    missing = []
    
    SkillAnalyzerService::DICTIONARY.each do |cat, skills|
      skills.each do |s|
        if desc.include?(s.downcase)
          if record.skills.map(&:downcase).include?(s.downcase)
            matched << s
          else
            missing << s
          end
        end
      end
    end
    
    matched = matched.uniq.first(8)
    missing = missing.uniq.first(8)
    
    if matched.empty? && missing.empty?
      matched = ['Git', 'REST API']
      missing = ['Docker', 'Kubernetes']
    end
    
    total_found = matched.size + missing.size
    score = total_found == 0 ? 50 : ((matched.size.to_f / total_found) * 100).round(0)
    score = [score, 30].max
    score = [score, 95].min
    
    if lang == 'tr'
      {
        'score' => score,
        'matched_keywords' => matched,
        'missing_keywords' => missing,
        'tailoring_suggestions' => [
          "Özgeçmişinizin en üstündeki profesyonel özet bölümüne iş ilanındaki anahtar kelimeleri (#{missing.first(3).join(', ')}) dahil edin.",
          "Projelerinizde kullandığınız teknolojileri açıkça listeleyin ve eksik olan becerileri projelerinize nasıl uyguladığınızı açıklayın.",
          "Sertifikalar veya eğitim geçmişi alanlarına ilgili ilan kriterleriyle örtüşen eğitimleri veya kişisel çalışmaları ekleyin."
        ]
      }
    else
      {
        'score' => score,
        'matched_keywords' => matched,
        'missing_keywords' => missing,
        'tailoring_suggestions' => [
          "Incorporate the key missing skills (#{missing.first(3).join(', ')}) directly into your resume's Summary or Profile section.",
          "Detail how you utilized target technologies in your project bullet points rather than just listing them in a skills grid.",
          "Highlight certifications or personal sandbox projects that demonstrate practical experience with #{missing.first(2).join(' & ')}."
        ]
      }
    end
  end
end
