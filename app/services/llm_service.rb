require 'net/http'
require 'uri'
require 'json'

class LLMService
  def self.grok_key(session_keys = {})
    SettingsService.grok_key
  end

  def self.active_model(session_keys = {})
    SettingsService.active_model
  end

  def self.configured?(session_keys = {})
    model = active_model(session_keys)
    case model
    when 'grok' then !grok_key(session_keys).nil?
    else
      !grok_key(session_keys).nil?
    end
  end

  # AI Parser to extract CV structures
  def self.parse_cv_text(raw_text, lang = 'en')
    prompt = <<~PROMPT
      Analyze the following raw resume text and extract all details into a structured JSON representation.
      Translate roles and descriptions if necessary, but keep original technical terms.
      
      Raw Resume Text:
      #{raw_text[0..3800]}
      
      You MUST return strictly valid JSON ONLY, matching this schema exactly:
      {
        "personal_info": {
          "name": "Extract Full Name (best guess from start of text)",
          "email": "Extract email address (or null if missing)",
          "phone": "Extract phone number (or null if missing)",
          "linkedin": "Extract linkedin username or profile path (or null if missing)",
          "github": "Extract github username or path (or null if missing)"
        },
        "education": [
          {
            "institution": "University/School name",
            "degree": "Degree (e.g. Computer Engineering, High School, etc.)",
            "year": "Graduation year or null",
            "gpa": "GPA or null"
          }
        ],
        "work_experience": [
          {
            "role": "Job Title (e.g., Software Developer)",
            "company": "Company Name",
            "duration": "Employment duration (e.g. 2022 - Present or 6 Months)",
            "description": "Short description of duties and accomplishments"
          }
        ],
        "projects": [
          {
            "title": "Project Title",
            "description": "Description of project features and stack"
          }
        ],
        "skills": [
          "List of technical/soft skills found (e.g., Ruby, Rails, Docker, Kotlin)"
        ]
      }
      
      IMPORTANT: Respond ONLY with the JSON structure. Do NOT wrap it in code blocks like ```json ... ```. Do NOT add any extra text or conversational filler.
    PROMPT

    res = query_llm(prompt, {}, true)

    if res.is_a?(String)
      cleaned = res.gsub(/^```json\s*/i, '').gsub(/```$/, '').strip
      begin
        JSON.parse(cleaned)
      rescue => e
        warn "Failed to parse LLM parser response: #{e.message}"
        nil
      end
    else
      res
    end
  end

  def self.generate_analysis(cv_text, target_role, detected_skills, missing_skills, lang = 'en', session_keys = {})
    prompt = if lang == 'tr'
               <<~PROMPT
                 Aşağıdaki CV metnini analiz et ve şu bilgileri içeren yapılandırılmış bir JSON üret:
                 1. Adayın şu hedef pozisyon için: #{target_role} eksik olan şu becerileri: #{missing_skills.join(', ')} kazanması için özelleştirilmiş 3 aylık bir Yol Haritası (roadmap).
                    Format: Her biri bir 'stage' (örn. "1. Ay - Temeller"), 'objective' (hedef) ve 3 adet 'tasks' (görev) içeren 3 aşamalı liste.
                 2. Adayın profiline ve eksikliklerine özel olarak hazırlanmış 3 adet Mülakat Hazırlık Sorusu (interview_prep).
                    Her biri 'question' (soru), 'context' (sorulma amacı) ve 'suggested_answer' (örnek cevap) içermelidir.
                 
                 ÖNEMLİ: Tüm içerikleri TÜRKÇE olarak üret.
                 
                 CV Metni:
                 #{cv_text[0..2500]}
                 
                 Yalnızca geçerli JSON döndür:
                 {
                   "roadmap": [
                     {
                       "stage": "1. Ay",
                       "objective": "Açıklama...",
                       "tasks": ["Görev 1", "Görev 2", "Görev 3"]
                     }
                   ],
                   "interview_prep": [
                     {
                       "question": "Soru...",
                       "context": "Neden sorulur...",
                       "suggested_answer": "Verilmesi gereken cevap..."
                     }
                   ]
                 }
               PROMPT
             else
               <<~PROMPT
                 Analyze the following CV text and generate a structured JSON containing:
                 1. A customized 3-month Roadmap for acquiring the missing skills: #{missing_skills.join(', ')} for the target role: #{target_role}.
                    Format as a list of stages (Month 1, Month 2, Month 3), each with an 'stage' title, 'objective', and 3 'tasks'.
                 2. 3 tailored Interview Prep Questions based on their profile gaps, each with 'question', 'context', and 'suggested_answer'.
                 
                 IMPORTANT: Respond strictly in English.
                 
                 CV Content:
                 #{cv_text[0..2500]}
                 
                 Respond STRICTLY in JSON format with keys:
                 {
                   "roadmap": [
                     {
                       "stage": "Month 1",
                       "objective": "Objective description...",
                       "tasks": ["task 1", "task 2", "task 3"]
                     }
                   ],
                   "interview_prep": [
                     {
                       "question": "Question text...",
                       "context": "Why this is asked...",
                       "suggested_answer": "Suggested response..."
                     }
                   ]
                 }
               PROMPT
             end

    query_llm(prompt, session_keys, true)
  end

  def self.chat_response(cv_text, message, history, lang, session_keys = {})
    history_text = history.map { |h| "#{h['role'] == 'user' ? 'Candidate' : 'CareerMind AI'}: #{h['content']}" }.join("\n")
    
    prompt = if lang == 'tr'
               <<~PROMPT
                 Sen CareerMind AI platformunun profesyonel kariyer danışmanısın.
                 Adayın CV İçeriği:
                 #{cv_text[0..2500]}

                 Mevcut Sohbet Geçmişi:
                 #{history_text}

                 Adayın Yeni Mesajı:
                 #{message}

                 Lütfen adaya doğrudan, kibar ve profesyonel bir şekilde yanıt ver. Yanıtında adayın CV'sindeki bilgileri referans al.
                 ÖNEMLİ: Türkçe olarak yanıt ver. Gereksiz giriş veya etiket kullanmadan doğrudan cevabı yaz.
               PROMPT
             else
               <<~PROMPT
                 You are the professional CareerMind AI consultant.
                 Candidate's CV Content:
                 #{cv_text[0..2500]}

                 Chat History:
                 #{history_text}

                 Candidate's New Message:
                 #{message}

                 Please reply directly to the candidate in a helpful, professional tone, referencing their background if relevant.
                 IMPORTANT: Respond in English. Output only your response directly.
               PROMPT
             end

    query_llm(prompt, session_keys, false)
  end

  def self.evaluate_interview_answer(question, candidate_answer, cv_text, lang, session_keys = {})
    prompt = if lang == 'tr'
               <<~PROMPT
                 Adayın şu sorusuna verdiği cevabı değerlendir:
                 Soru: #{question}
                 Adayın Cevabı: #{candidate_answer}
                 
                 Adayın CV Özeti:
                 #{cv_text[0..2000]}
                 
                 Şu bilgileri içeren geçerli bir JSON döndür:
                 1. "score": 100 üzerinden bir başarı puanı (tamsayı).
                 2. "strengths": Adayın cevabında neleri iyi açıkladığına dair 2 maddelik liste.
                 3. "gaps": Adayın eksik bıraktığı veya daha iyi açıklayabileceği 2 teknik/davranışsal nokta.
                 4. "refined_answer": Adayın arka planını ve doğru terminolojiyi birleştirerek hazırlanmış ideal, profesyonel örnek cevap.
                 
                 ÖNEMLİ: Cevapları Türkçe olarak üret. Geçersiz hiçbir karakter veya JSON dışı metin ekleme.
               PROMPT
             else
               <<~PROMPT
                 Evaluate the candidate's response to this interview question:
                 Question: #{question}
                 Candidate's Answer: #{candidate_answer}
                 
                 Candidate CV Summary:
                 #{cv_text[0..2000]}
                 
                 Return a strictly valid JSON containing:
                 1. "score": An integer score out of 100.
                 2. "strengths": A list of 2 points they explained well.
                 3. "gaps": A list of 2 points they missed or could explain better.
                 4. "refined_answer": A refined, professional recommended response combining their background and appropriate technical terminology.
                 
                 IMPORTANT: Respond in English. Do not add any conversational text outside the JSON.
               PROMPT
             end

    query_llm(prompt, session_keys, true)
  end

  def self.align_job(cv_text, job_desc, lang, session_keys = {})
    prompt = if lang == 'tr'
               <<~PROMPT
                 Adayın CV'sini hedef iş tanımına göre analiz et:
                 İş Tanımı:
                 #{job_desc[0..2000]}
                 
                 CV İçeriği:
                 #{cv_text[0..2000]}
                 
                 Şu bilgileri içeren geçerli bir JSON döndür:
                 1. "score": Adayın bu işe uyumluluk yüzdesi (100 üzerinden tamsayı).
                 2. "matched_keywords": İş tanımında geçen ve adayın CV'sinde bulunan teknik anahtar kelimeler/beceriler (liste).
                 3. "missing_keywords": İş tanımında yer alan ancak adayın CV'sinde eksik olan kritik anahtar kelimeler/beceriler (liste).
                 4. "tailoring_suggestions": Adayın bu pozisyona kabul edilme şansını artırmak için özgeçmişinde yapması gereken 3 adet özelleştirilmiş öneri (liste).
                 
                 ÖNEMLİ: Türkçe olarak üret. Sadece JSON döndür.
               PROMPT
             else
               <<~PROMPT
                 Analyze the candidate's CV against this target job description:
                 Job Description:
                 #{job_desc[0..2000]}
                 
                 CV Content:
                 #{cv_text[0..2000]}
                 
                 Return a strictly valid JSON containing:
                 1. "score": Match percentage out of 100 (integer).
                 2. "matched_keywords": List of matching technical keywords/skills found in both.
                 3. "missing_keywords": List of key technical keywords/skills present in the job description but missing from the CV.
                 4. "tailoring_suggestions": List of 3 actionable resume tuning suggestions to align the CV with this job.
                 
                 IMPORTANT: Respond in English. Do not add any conversational text outside the JSON.
               PROMPT
             end

    query_llm(prompt, session_keys, true)
  end

  private

  def self.query_llm(prompt, session_keys = {}, is_json = false)
    model = active_model(session_keys)

    res = case model
          when 'grok'
            call_grok(prompt, session_keys, is_json)
          else
            if !grok_key(session_keys).nil?
              call_grok(prompt, session_keys, is_json)
            else
              nil
            end
          end

    res
  end

  def self.call_grok(prompt, session_keys = {}, is_json = false)
    key = grok_key(session_keys)
    return nil if key.nil?

    uri = URI("https://api.x.ai/v1/chat/completions")
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{key}"
    
    body_data = {
      model: "grok-2",
      messages: [
        { role: "system", content: "You are a helpful, professional career consultant." },
        { role: "user", content: prompt }
      ]
    }
    body_data[:response_format] = { type: "json_object" } if is_json

    req.body = body_data.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.read_timeout = 25
      http.request(req)
    end

    if res.code == '200'
      json = JSON.parse(res.body)
      text = json['choices']&.first&.[]('message')&.[]('content')
      is_json ? (JSON.parse(text) rescue text) : text
    else
      warn "Grok API failed: #{res.body}"
      nil
    end
  rescue => e
    warn "Grok call error: #{e.message}"
    nil
  end
end
