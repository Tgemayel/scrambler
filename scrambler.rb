require 'openssl'
require 'base64'
require 'thor'
require 'securerandom'
require 'logger'
require 'fileutils'

class Scrambler < Thor
  class Error < StandardError; end
  
  def self.logger
    @logger ||= Logger.new('scrambler.log').tap do |log|
      log.level = Logger::INFO
      log.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime} [#{severity}] #{msg}\n"
      end
    end
  end

  desc "encrypt PATTERN OUTPUT_DIR", "Encrypt (and optionally scramble) markdown files matching pattern"
  option :key_file, type: :string, desc: "Path to save/load the encryption key"
  option :scramble, type: :boolean, default: false, desc: "Scramble text before encryption"
  option :backup, type: :boolean, default: true, desc: "Create backups of original files"
  def encrypt(pattern, output_dir)
    begin
      FileUtils.mkdir_p(output_dir)
      key = load_or_generate_key(options[:key_file])
      files = Dir.glob(pattern).select { |f| valid_markdown_file?(f) }
      
      if files.empty?
        raise Error, "No valid markdown files found matching pattern: #{pattern}"
      end

      results = process_files(files, output_dir, key, :encrypt)
      report_results(results)
      
      if options[:key_file] && !File.exist?(options[:key_file])
        File.write(options[:key_file], key)
        self.class.logger.info("Saved key to: #{options[:key_file]}")
      end

    rescue Error => e
      self.class.logger.error(e.message)
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "decrypt PATTERN OUTPUT_DIR KEY", "Decrypt encrypted markdown files matching pattern"
  option :backup, type: :boolean, default: true, desc: "Create backups of original files"
  def decrypt(pattern, output_dir, key)
    begin
      FileUtils.mkdir_p(output_dir)
      files = Dir.glob(pattern)
      
      if files.empty?
        raise Error, "No files found matching pattern: #{pattern}"
      end

      results = process_files(files, output_dir, key, :decrypt)
      report_results(results)

    rescue Error => e
      self.class.logger.error(e.message)
      puts "Error: #{e.message}"
      exit 1
    end
  end

  private

  def process_files(files, output_dir, key, operation)
    results = { success: [], failure: [] }
    
    files.each do |input_file|
      begin
        output_file = File.join(output_dir, File.basename(input_file))
        create_backup(input_file) if options[:backup]
        
        case operation
        when :encrypt
          content = File.read(input_file, encoding: 'utf-8')
          content = scramble_text(content) if options[:scramble]
          encrypted = encrypt_content(content, key)
          File.write(output_file, encrypted)
        when :decrypt
          encrypted = File.read(input_file)
          decrypted = decrypt_content(encrypted, key)
          File.write(output_file, decrypted, encoding: 'utf-8')
        end
        
        results[:success] << input_file
        self.class.logger.info("Successfully processed: #{input_file}")
        
      rescue StandardError => e
        results[:failure] << { file: input_file, error: e.message }
        self.class.logger.error("Failed to process #{input_file}: #{e.message}")
      end
    end
    
    results
  end

  def valid_markdown_file?(file)
    return false unless File.file?(file)
    return false unless file.end_with?('.md', '.markdown')
    
    begin
      content = File.read(file, encoding: 'utf-8')
      return content.match?(/[\#\-\*\`]/)
    rescue
      false
    end
  end

  def create_backup(file)
    backup_file = "#{file}.#{Time.now.strftime('%Y%m%d_%H%M%S')}.bak"
    FileUtils.cp(file, backup_file)
    self.class.logger.info("Created backup: #{backup_file}")
  end

  def load_or_generate_key(key_file)
    if key_file && File.exist?(key_file)
      File.read(key_file)
    else
      SecureRandom.base64(32)
    end
  end

  def report_results(results)
    puts "\nProcessing Summary:"
    puts "==================="
    puts "Successfully processed: #{results[:success].length} files"
    
    if results[:failure].any?
      puts "\nFailed to process: #{results[:failure].length} files"
      results[:failure].each do |failure|
        puts "  #{failure[:file]}: #{failure[:error]}"
      end
    end
  end

  def scramble_text(text)
    patterns = [
      [/(\*\*.*?\*\*)/, 'bold'],
      [/(\*.*?\*)/, 'italic'],
      [/(\_.*?\_)/, 'underscore'],
      [/(\[.*?\])/, 'bracket'],
      [/(\(.*?\))/, 'parenthesis'],
      [/(\#.*?\n)/, 'heading'],
      [/(\`.*?\`)/, 'code'],
      [/(\`\`\`[\s\S]*?\`\`\`)/, 'codeblock']
    ]

    replacements = {}
    counter = 0

    patterns.each do |pattern, name|
      text.scan(pattern) do |match|
        placeholder = "__PLACEHOLDER_#{counter}__"
        replacements[placeholder] = match[0]
        text = text.gsub(match[0], placeholder)
        counter += 1
      end
    end

    scrambled_text = text.split(/\s+/).map do |word|
      if word.start_with?('__PLACEHOLDER_')
        word
      else
        scramble_word_completely(word)
      end
    end.join(' ')

    replacements.each do |placeholder, original|
      scrambled_text = scrambled_text.gsub(placeholder, original)
    end

    scrambled_text
  end

  def scramble_word_completely(word)
    return word if word.length <= 1
    
    charset = ('a'..'z').to_a + ('A'..'Z').to_a
    special_chars = '!@#$%^&*'.chars
    
    new_word = word.chars.map do |char|
      if char.match?(/[a-zA-Z]/)
        if rand < 0.8  # 80% chance of letter
          charset.sample
        else
          special_chars.sample
        end
      else
        char
      end
    end.join

    if rand < 0.3  # 30% chance to modify length
      if rand < 0.5
        new_word += charset.sample(rand(1..3)).join
      else
        new_word = new_word[0...-rand(1..3)] unless new_word.length <= 1
      end
    end

    new_word
  end

  def encrypt_content(content, key)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = Base64.decode64(key)
    iv = cipher.random_iv
    encrypted = cipher.update(content) + cipher.final
    Base64.strict_encode64(iv + encrypted)
  end

  def decrypt_content(encrypted_content, key)
    encrypted_data = Base64.decode64(encrypted_content)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.decrypt
    cipher.key = Base64.decode64(key)
    iv = encrypted_data[0, 16]
    cipher.iv = iv
    decrypted = cipher.update(encrypted_data[16..-1]) + cipher.final
    decrypted
  end
end

Scrambler.start(ARGV) if __FILE__ == $0
