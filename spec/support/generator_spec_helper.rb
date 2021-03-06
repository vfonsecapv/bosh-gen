require "bosh/gen/cli"

module GeneratorSpecHelper
  def setup_universe
    @@local_developer_bosh_config ||= File.expand_path("~/.bosh_config") # ENV['HOME'] messed with later
    @tmp_root      = File.expand_path("../../tmp", __FILE__)
    @home_path     = File.join(@tmp_root, "home")
    @fixtures_path = File.expand_path('../../fixtures', __FILE__)
    FileUtils.rm_rf   @tmp_root
    FileUtils.mkdir_p @home_path
    ENV['HOME'] = @home_path
    if File.exists?(@@local_developer_bosh_config)
      FileUtils.cp_r(@@local_developer_bosh_config, @home_path)
    end
    setup_git
  end

  def setup_project_release(name)
    release_path = File.join(@fixtures_path, "releases", name)
    FileUtils.cp_r(release_path, @tmp_root)
    @active_project_folder = File.join(@tmp_root, name)
  end

  def setup_git
    in_home_folder do
      git config: "--global user.name 'Dr Nic Williams'"
      git config: "--global user.email 'drnic@starkandwayne.com'"
    end
  end

  # generate_new_release 'redis'
  # generate_new_release 'redis-boshrelease'
  # generate_new_release 'redis', '--s3'
  # generate_new_release 'redis', '--swift'
  def generate_new_release(*args)
    stdout, stderr = capture_stdios do
      Bosh::Gen::Command.start(["new", *args])
    end
    @stdout = File.expand_path(File.join(@tmp_root, "generate_release.out"))
    File.open(@stdout, "w") {|f| f << stdout; f << stderr}
  end

  # Runs 'bosh-gen job NAME ...'
  #
  # generate_job 'JOBNAME'
  # generate_job 'JOBNAME', '-d', 'nginx'
  # generate_job "JOBNAME", "--template", "nginx_rack", '-d', 'nginx', 'ruby', 'myapp'
  def generate_job(*args)
    stdout, stderr = capture_stdios do
      Bosh::Gen::Command.start(["job", *args])
    end
    @stdout = File.expand_path(File.join(@tmp_root, "generate_job.out"))
    File.open(@stdout, "w") {|f| f << stdout; f << stderr}
  end

  # Runs 'bosh-gen manifest path/to/release'
  # generate_manifest "path/to/release"
  def generate_manifest(*args)
    stdout, stderr = capture_stdios do
      Bosh::Gen::Command.start(["manifest", *args])
    end
    @stdout = File.expand_path(File.join(@tmp_root, "generate_manifest.out"))
    File.open(@stdout, "w") {|f| f << stdout; f << stderr}
  end

  # Test that a file exists in job
  #   job_file_exists "mywebapp", "monit"
  #   job_file_exists "mywebapp", "templates", "mywebapp_ctl", :executable => true
  def job_file_exists(*args)
    if args.last.is_a?(Hash)
      options = args.pop
    end
    path = File.join(["jobs"] + args) # jobs/JOBNAME/monit
    expect(File.exist?(path)).to eq(true)
    if options && options[:executable]
      expect(File.executable?(path)).to eq(true)
    end
  end

  # Tests a job template and its spec
  #   job_template_exists "mywebapp", "mywebapp_ctl.erb", "bin/mywebapp_ctl"
  #
  # Spec would contain:
  #   mywebapp_ctl.erb: bin/mywebapp_ctl
  def job_template_exists(job, template_name, spec_path)
    path = File.join("jobs", job, "templates", template_name)
    expect(File.exist?(path)).to eq(true)
    spec_templates = job_spec(job)["templates"]
    expect(spec_templates[template_name]).to_not be_nil
    expect(spec_templates[template_name]).to eq(spec_path)
  end

  def job_spec(job)
    @specs ||= {}
    @specs[job] ||= YAML.load_file(File.join("jobs", job, "spec"))
  end

  def setup_active_project_folder project_name
    @active_project_folder = File.join(@tmp_root, project_name)
    @project_name = project_name
  end

  def in_tmp_folder(&block)
    FileUtils.chdir(@tmp_root, &block)
  end

  def in_project_folder(&block)
    project_folder = @active_project_folder || @tmp_root
    FileUtils.chdir(project_folder, &block)
  end

  def in_home_folder(&block)
    FileUtils.chdir(@home_path, &block)
  end

  def capture_stdios(input = nil, &block)
    require 'stringio'
    org_stdin, $stdin = $stdin, StringIO.new(input) if input
    org_stdout, $stdout = $stdout, StringIO.new
    org_stderr, $stderr = $stdout, StringIO.new
    yield
    return [$stdout.string, $stderr.string]
  ensure
    $stderr = org_stderr
    $stdout = org_stdout
    $stdin = org_stdin
  end

  def get_command_output
    strip_color_codes(File.read(@stdout)).chomp
  end

  def strip_color_codes(text)
    text.gsub(/\e\[\d+m/, '')
  end

  # Run a command in git.
  #
  # ==== Examples
  #
  #   git :init
  #   git :add => "this.file that.rb"
  #   git :add => "onefile.rb", :rm => "badfile.cxx"
  #
  def git(commands={})
    if commands.is_a?(Symbol)
      `git #{commands}`
    else
      commands.each do |cmd, options|
        `git #{cmd} #{options}`
      end
    end
  end

end
