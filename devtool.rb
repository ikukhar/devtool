
class Devtool

  def initialize
    
    init
    load_ui
    tune_window
    get_environments
    refresh_left_pane
    apply_css_style
    @window.show_all

    attach_console

    on_env_choised @envs[:all].first if @envs[:all]
    
    Gtk.main

  end

  def init

    init_pixbuf

    @envs   = {}
    @files  = {}
    @close_tasks = []

    @sql = TinyTds::Client.new(username: 'sa', password: 'Rdflhjwbrk', host: 'sql8adm', database: 'Development')

    @findWindow   = Win32API.new('user32','FindWindow',  'PP',     'L')
    @setWindowPos = Win32API.new('user32','SetWindowPos','LLIIIII','V')
    
  end

  def init_pixbuf

    @pixbuf = {}
    @pixbuf[:untracked] = Gdk::Pixbuf.new(file: 'icons/new-file.png')
    @pixbuf[:changed]   = Gdk::Pixbuf.new(file: 'icons/edit-file.png')
    @pixbuf[:deleted]   = Gdk::Pixbuf.new(file: 'icons/delete-file.png')

  end

  def load_ui

    @builder = Gtk::Builder.new
    @builder.add_from_file('glade.ui')
    @builder.connect_signals {|handler| method(handler) }

    @window  = @builder['window']
    
  end

  def set_window_pos

    x, y = @window.position
    devtool = @findWindow.call('gdkWindowToplevel', 'Devtool'.encode('cp1251'))
    @setWindowPos.call(devtool, 0, x-225, y, 0, 0, 0x0040)

  end

  def attach_console

    console = @findWindow.call('ConsoleWindowClass', 'main.rb - Ярлык'.encode('cp1251'))
    
    if console > 0

      set_window_pos

      Thread.new(console) do
        loop do
        
          x, y = @window.position

          if @xpos_window != x || @ypos_window != y
            
            @xpos_window, @ypos_window = x, y
            width = @window.width_request 
            height = @window.height_request
            
            @setWindowPos.call(console, 0, x+width+7, y, 550, height+40, 0x0040)

          end
        
          sleep(0.5)

        end
      end
    end

  end

  def add_item_on_file_box(file, status)

    @files[file] = {status: status, selected: false}

    item_box = Gtk::Box.new(:horizontal, 3)

    cb  = Gtk::CheckButton.new
    cb.set_margin_left 5
    img = Gtk::Image.new(pixbuf: @pixbuf[status])
    lb  = Gtk::LinkButton.new(file)

    cb.set_tooltip_text(status)
    img.set_tooltip_text(status)
    lb.set_tooltip_text(case status
                        when :untracked
                          'Open file'
                        when :changed
                          'Open difftool'
                        else
                         ''
                        end)

    item_box.add(cb)
    item_box.add(img)
    item_box.add(lb)

    @builder['files_box'].add(item_box)

    cb.signal_connect :toggled do |cb|
      on_file_selected(item_box, cb.active?, file)
    end

    lb.signal_connect :activate_link do
      on_file_choised(file, status)
    end

    @window.show_all

  end

  def add_items_on_env_box

    @builder['env_box'].each { |item_box| item_box.destroy}

    @envs[:all].each do |env|

      item_box = Gtk::Box.new(:horizontal, 2)
      lb  = Gtk::LinkButton.new(env[:name])
      lb.set_name(env[:name])
      lb.set_tooltip_text(env[:path])
      lb.style_context.add_class('current_env') if env == @envs[:current]

      # Menu do
      # tb = Gtk::Toolbar.new
      # menutb = Gtk::MenuToolButton.new
      
      # menu = Gtk::Menu.new
      # mitem = Gtk::MenuItem.new("Run configurator")
      # # mitem.signal_connect "activate" do
      # #   run_configurator
      # # end
      # menu.add(mitem)

      # mitem = Gtk::MenuItem.new("Delete environment")
      
      # # mitem.signal_connect "activate" do
      # #   run_configurator
      # # end
      # menu.add(mitem)
      
      # menutb.add(menu)
      # tb.add(menutb)
      # end
      
      item_box.add(lb)
      # item_box.add(tb)
      @builder['env_box'].add(item_box)

      lb.signal_connect :activate_link do
        on_env_choised(env)
      end

    end
  end

  def git_command text

    ENV['GIT_DIR']        = "#{@envs[:current][:path]}/.git"
    ENV['GIT_WORK_TREE']  = "#{@envs[:current][:path]}"
    ENV['GIT_INDEX_FILE'] = "#{@envs[:current][:path]}/.git/index"
    
    cmd = "git #{text}"
  	async_exec(cmd)
    
  end

  def git_status

  	@builder['files_box'].each { |item_box| item_box.destroy}

    repo = Git.open(@envs[:current][:path])
    %w[untracked deleted changed].each do |status|
      repo.status.method(status).call.each_value do |file|
        add_item_on_file_box(file.path, status.to_sym)
      end
    end

  end

  def tune_window

    @window.set_title 'Devtool'
    @builder['name'].label      = DEVELOPER
    @builder['email'].label     = get_dev_mail

  end

  def get_dev_mail

    ldap = Net::LDAP.new
    ldap.host = '192.168.1.220'
    ldap.port = 389
    ldap.auth("gazzap\\i.tunik", "15stpct9")

    if ldap.bind
      ldap.search(:base => 'DC=local,DC=gazzap,DC=zp,DC=ua' ,:filter => "(samaccountname=#{DEVELOPER})") do |entry|
        mail = entry['mail'][0]
        return mail
      end
    end

    nil

  end

  def get_environments
    
    all = []
    
    result = @sql.execute("
      select * 
      from Environments 
      where UserName = '#{DEVELOPER}' 
      and inUse = 1 ORDER BY envName
    ")
    
    count_env = result.count
    if count_env > 0
      result.each do |entry|
        all << {name: entry['envName'], maxid: entry['maxId'], path: (BASEDIR + "#{entry['envName']}\\")}
      end 
    end
    
    if all.count > 0
      @envs[:all]     = all
      @envs[:current] = all.first
    else
      @envs[:all]     = nil
      @envs[:current] = nil
    end

  end

  def refresh_right_pane

    git_command 'reset .'
    git_status

  end

  def refresh_left_pane
     	
    add_items_on_env_box if @envs[:all]

  end

  def async_exec(cmd, change_encoding=false)

  	# stdout_text_buffer = @builder['stdout_text'].buffer
  	# adj = @builder['stdout_sw'].vadjustment

  	# iter = stdout_text_buffer.end_iter
  	time = Time.now.strftime("%F %T")
  	# stdout_text_buffer.insert(iter, "\n #{time} : #{cmd}\n\n")
    puts "\n #{time} : #{cmd}\n\n"

  	Thread.new do
    	Encoding.default_external = 'ibm866' if change_encoding

      Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
        while line = stdout_err.gets
          line = line.encode('utf-8') if change_encoding
          puts line
          # stdout_text_buffer.insert(iter, " #{line}") 
          # refresh_window
          # adj.value = adj.upper + 10
        end

      #   exit_status = wait_thr.value
      #   unless exit_status.success?
      #     abort "FAILED !!! #{cmd}"
      #   end
       end

      Encoding.default_external = 'utf-8'  if change_encoding
  	end.join
    
  end

  def run_script name

    ENV.delete 'GIT_DIR'
    ENV.delete 'GIT_WORK_TREE'
    ENV.delete 'GIT_INDEX_FILE'

  	cmd = "#{@envs[:current][:path]}/scripts/#{name}.bat"
  	async_exec(cmd, true)
  	
  end

  def select_files active

    @builder['files_box'].each do |item_box|
      item_box.each do |widget|
        if widget.instance_of? Gtk::CheckButton
          widget.set_active(active)
        end
      end
    end

  end

  def apply_css(widget, provider)
    
    widget.style_context.add_provider(provider, GLib::MAXUINT)
    
    if widget.is_a?(Gtk::Container)
      widget.each do |child|
        apply_css(child, provider)
      end
    end

  end

  def apply_css_style

  	css = File.read(File.join(__dir__, "style.css"))
  	provider = Gtk::CssProvider.new
  	provider.load(data: css)
  	apply_css(@window, provider)

  end

  def refresh_window
  	
    while Gtk.events_pending? do
     	Gtk.main_iteration_do(false)
    end

  end

  def show_message text
    
    dialog = Gtk::MessageDialog.new(flags: [:modal, :destroy_with_parent],
                                    type: :info,
                                    buttons_type: :ok,
                                    message: text)
    dialog.set_transient_for(@window)                                
    dialog.signal_connect(:response) {dialog.destroy}
    dialog.show_all

  end

  def check_remote_repo

  #   pull = @builder['pull_tbtn']
  #   push = @builder['push_tbtn']

  #   pull.set_sensitive(false)
  #   push.set_sensitive(false)
  #   pull.style_context.remove_class('push_me')
  #   push.style_context.remove_class('push_me')

  #   status = git_remote_status

  #   if sql_diffs? || ([:need_to_pull, :diverged].include? status) 

  #     pull.set_sensitive(true)
  #     pull.style_context.add_class('push_me')

  #   elsif status == :need_to_push
      
  #     push.set_sensitive(true)
  #     push.style_context.add_class('push_me')

  end

  # end

  # def sql_diffs?
  #   
  #   result = @sql.execute("
  #     select count(*) 
  #     from dbo.SqlDiffs 
  #     where [datetime] > (select isnull(max(DateTime),0) 
  #                         from #{@envs[:current][:name]}.dbo.SchemaPullDateTime)")
    
  #   return true ? result.count > 0 : false

  # end

  # def git_remote_status

  #   Dir.chdir @envs[:current][:path] do
  #     local  = `git rev-parse @`
  #     remote = `git rev-parse @{u}`
  #     base   = `git merge-base @ @{u}`
    
  #     if local == remote
  #       :up_to_date
  #     elsif remote == base
  #       :need_to_pull
  #     elsif local == base
  #       :need_to_push
  #     else
  #       :diverged
  #     end
  #   end

  # end

  def refresh_all
   
    get_environments
    refresh_left_pane
    apply_css_style
    on_env_choised @envs[:all].first

  end

  def refresh_tasks
   
    @builder['tasks_box'].each { |item_box| item_box.destroy}

    Redmine.mytasks.each do |task|

      item_box = Gtk::Box.new(:horizontal, 3)

      cb  = Gtk::CheckButton.new
      cb.set_margin_left(5)
      cb.set_active(@close_tasks.include?(task.id))

      lb  = Gtk::LinkButton.new task.subject
      lb.set_tooltip_text('View in browser')

      item_box.add(cb)
      item_box.add(lb)

      @builder['tasks_box'].add(item_box)

      cb.signal_connect :toggled do |cb|
        on_task_selected(item_box, cb.active?, task.id)
      end

      lb.signal_connect :activate_link do
        on_task_choised(task.id)
      end

    end
  end

  def run_configurator

  end

  def delete_environment

    dialog = Gtk::MessageDialog.new(flags: [:modal, :destroy_with_parent],
                                  type: :question,
                                  buttons_type: :yes_no,
                                  message: "Delete environment #{@envs[:current][:name]}?")
    dialog.set_transient_for(@window)                                
    response = dialog.run
    if response == Gtk::ResponseType::YES
      dialog.destroy
      Dir.chdir BASEDIR do
        async_exec("delete_env #{@envs[:current][:name]}", true) 
      end
      refresh_all
    else
      dialog.destroy
    end
  end 
end