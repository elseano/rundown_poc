#!/usr/bin/env ruby
require_relative "bundle/bundler/setup"

require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require "kramdown"
require "tty-markdown"
require "tempfile"
require "tty-spinner"
require "tty-prompt"
require "tty-command"
require "logger"
require "pry"
require "inifile"
require "pathname"

class TTY::Markdown::Parser
  def convert_codespan(node, opts)
    opts[:result] << @pastel.bright_blue.bold(node.value)
  end

  def convert_br(node, _)
    "\n"
  end

  def convert_codeblock(el, opts)
    opts[:fenced] = false

    raw_code = Strings.wrap(el.value, @width)
    highlighted = ::TTY::Markdown::SyntaxHighliter.highlight(raw_code, @color_opts.merge(opts).merge(lang: el.options[:lang]))

    code = highlighted.split("\n").map.with_index do |line, i|
            if i.zero? # first line
              line
            else
              line.insert(0, ' ' * @current_indent)
            end
          end
    opts[:result] << code.join("\n")
  end


end

module TTY::Markdown::SyntaxHighliter
  def highlight(code, **options)
    lang = options[:lang] || guess_lang(code)
    mode = options[:mode] || TTY::Color.mode
    lines = code.dup.lines
    if options[:fenced].nil?
      code = lines[1...-1].join + lines[-1].strip
    end

    lexer = Rouge::Lexer.find_fancy(lang, code) || Rouge::Lexers::PlainText

    if mode >= 256
      formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::Github.new)
      formatter.format(lexer.lex(code))
    else
      pastel = Pastel.new
      code.split("\n").map { |line| pastel.yellow.on_black(line) }.join("\n")
    end
  end
  module_function :highlight

end

class Rundown
  THEME = {
    em: [:italic],
    header: [:cyan, :bold],
    hr: :green,
    link: [:blue, :underline],
    list: :green,
    strong: [:green, :bold],
    table: :blue,
    quote: :blue,
  }

  attr_reader :logger

  def initialize(script, log_file, dry_run = false)
    @script_file = Pathname.new(script).realpath
    @script_dir = @script_file.join("..")
    
    doc_contents = IO.read(@script_file)

    # Switch from triple-back-tick to triple-tilda, which works better with Kramdown.
    # doc_contents.gsub!("``` ", "~~~").gsub!("```", "~~~")

    @doc = Kramdown::Document.new(doc_contents, input: "GFM")
    @dry_run = dry_run

    @log_file = if log_file
      Pathname.new(log_file)
    elsif ENV["HOME"]
      Pathname.new(ENV["HOME"]) / ".rundown" / @script_file.basename.sub_ext(".log")
    else
      @script_file.sub_ext(".log")
    end

    puts @log_file.to_s

    @log_file.dirname.mkdir unless @log_file.dirname.exist?
    
    @logger = Logger.new(@log_file)
    @pastel = Pastel.new

    @current_heading_level = 0
    @break_to_next_heading = false
    @heading_history = []
    @code_modifiers = []
  end

  def run
    logger << "\n\nRunning runbook\n"
    puts @pastel.dim("Running #{@script_file.basename}...")

    puts @doc.root.children.map(&:inspect)
    # binding.pry

    process_all(@doc.root.children)
  end

  def logger; @logger; end

  def process(child)
    return if @break_to_next_heading && child.type != :header
    @break_to_next_heading = false
      
    case child.type
    when :header
      @heading_history = []
      process_header(child)
      @already_newline = true
    when :blockquote
      process_bq(child)
    when :p
      process_p(child)
    when :codespan
      execute(child)
      @code_modifiers = []
    when :text
      process_bq(child)
    when :blank
      puts "\n" unless @already_newline || @last_block_code
      @already_newline = true
    when :codeblock
      execute(child)
    when :xml_comment
      @code_modifiers = child.value.sub("<!--", "").sub("-->", "").strip.split(/\s+/)
    end
  end

  def run_ruby(script)
    prompt = TTY::Prompt.new
    eval(script)
  end

  def get_task_name_from_script(script, opts)
    if opts.include?("named")
      script_lines = script.split("\n")
      task_name = script_lines[0].sub(/^.*?\s+/, "")
      
      return task_name, script_lines[1..-1].join("\n")
    else
      return "Running...", script
    end
  end

  def executable?(child)
    child && 
      ((child.type == :codespan && child.value.to_s.include?("\n")) ||
      (child.type == :codeblock))

  end

  def execute(child)
    mode, opts, script = if child.options[:lang]
      # Support GFM
      m, *o = child.options[:lang].strip.split(/\s+/)

      [m, o, child.value]
    else
      # Support Kramdown
      m, *s = child.value.split("\n")
      m, *o = m.strip.split(/\s+/)

      [m, o, script]
    end

    opts ||= []
    opts += @code_modifiers
    script = Array(script).join("\n")

    if opts.include?("display_only")
      puts_indented to_text(child)
      @last_block_code = false
      @already_newline = false
      @code_modifiers = []
      return
    end


    task_name, script = get_task_name_from_script(script, opts)



    if script == ""
      puts_indented "#{@pastel.red(TTY::Spinner::CROSS)} Empty script found. Ignoring."
      return
    end

    unless opts.include?("nospin")
      spinner = TTY::Spinner.new("#{indent_to_s}:spinner :task_name", success_mark: @pastel.green(TTY::Spinner::TICK), error_mark: @pastel.red(TTY::Spinner::CROSS), hide_cursor: true)
      spinner.update(task_name: task_name)
      spinner.auto_spin
    end

    cmd = TTY::Command.new(output: logger, color: false)

    begin

      err = []

      result = if @dry_run
        !opts.include?("skip_on_success")
      elsif mode == "ruby" && opts.include?("rundown")
        logger << "Running in-process ruby code\n"
        logger << script + "\n"

        case run_ruby(script)
        when true 
          true
        when false 
          false
        else
          true
        end
      else    
        temp = Tempfile.new

        mode = "sh" if mode == ""
        process = `which #{mode}`.chomp

        logger << "Executing script using #{process}\n"
        logger << script + "\n"
        
        f = temp.open
        f.write(script)
        f.close
        
        if opts.include?("interactive")
          logger << "Running script in interactive mode, output ommitted.\n"
          system(process, temp.path)
        else
          result = cmd.run!("#{process} #{temp.path}", chdir: @script_dir, color: false) do |stdout, stderr|
            puts stdout if opts.include?("reveal")
            err << stderr
          end
          !result.failure?
        end

      end

      if opts.include?("skip_on_failure")
        if result == false
          spinner && spinner.success(@pastel.dim("(Not required)"))
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script failure with skip_on_failure, skipping to next heading\n"
        else
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        end
      elsif opts.include?("skip_on_success")
        if result == true
          spinner && spinner.success(@pastel.dim("(Not required)"))
          @heading_history << @pastel.dim("-")
          @break_to_next_heading = true
          logger << "Script success with skip_on_success, skipping to next heading\n"
        else
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        end
      else
        if result
          spinner && spinner.success(@pastel.dim("(Done)"))
          @heading_history << @pastel.bright_green(".")
        else
          spinner && spinner.error(@pastel.dim("(Failed)"))

          logger << "Script failed. Aborting.\n"
          @heading_history << @pastel.red("x")
          # puts_indented "#{@heading_history.join(' ')}\r"

          puts "\n\n"

          puts @pastel.red.bold("Error Running Script")
          puts @pastel.dim(script)
          puts "\n\n"

          puts @pastel.red(err.join("\n"))

          puts "\n"
          puts "Check the log file at #{@log_file} for more details."

          puts "\n❌ Failed/Aborted.\n\n"

          exit(-1)
        end  
      end

    ensure
      temp&.close(true)
      spinner && spinner.stop
    end

    # print_indented "#{@heading_history.join(' ')}\r"
    @last_block_code = true
    @code_modifiers = []
  end

  def process_header(header)
    @current_heading_level  = header.options[:level]
    puts "\n" if @last_block_code || !@already_newline
    puts "\n"
    puts to_text(header)
    @last_block_code = false
  end

  def process_bq(bq)
    @already_newline = false
    @last_block_code = false
    puts_indented to_text(bq)
  end

  def code_modifier?(child)
    child.attr["href"] =~ /^[a-z\s_]+$/ && child.value.nil?
  end

  def process_p(p)
    executable, _display = p.children.partition { |c| executable?(c) }
    code_modifiers, display = _display.partition { |c| code_modifier?(c) }

    binding.pry if $trap

    stripped_p = p.dup
    stripped_p.children = display

    result = to_text(stripped_p)
    puts_indented result #unless result.join.strip == ""

    @code_modifiers += code_modifiers.flat_map { |cm| cm.attr["href"].to_s.split(/\s+/) }

    if executable.length > 0
      process(executable[0])
    end

    @already_newline = false
  end

  def process_all(children)
    children.each do |child|
      process(child)
    end
  end

  def to_text(children)
    doc = @doc.dup
    doc.root.children = Array(children)
    TTY::Markdown::Parser.convert(doc.root, doc.options.merge({ theme: THEME })).map do |line|
      line.join.split("\n")
    end.flatten
  end

  def indent_to_s(offset = 0)
    ("  " * (@current_heading_level - 1 + offset))
  end

  def puts_indented(text)
    # binding.pry
    Array(text).join("\n").strip.split("\n").each do |line|      
      puts(indent_to_s + line)
    end
  end

  def print_indented(text)
    print(indent_to_s + text)
  end
end

class CLI < Thor
  def self.exit_on_failure?
    true
  end

  desc "[FILENAME]", "Executes a markdown file."
  option :log
  options :dryrun => false
  def execute(script_file)
    begin
      rundown = Rundown.new(script_file, options["log"], options["dryrun"])
      rundown.run
      puts "\n✅ Finished.\n"
      rundown.logger << "Runbook finished.\n"
      exit(0)
    rescue Interrupt
      rundown.logger << "Runbook aborted by user.\n"
      puts Pastel.new.red("\n❌ User Aborted")
      exit(1)
    rescue Errno::ENOENT
      puts Pastel.new.red("#{script_file} not found.")
      exit(2)
    end
  end
end

args = ARGV.dup
args.unshift("execute") unless args[0] == "help"

CLI.start(args)
