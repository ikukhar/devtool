# =================== MISC ====================

def on_window_destroy
  
  Gtk.main_quit

end

def on_env_choised env
  # show_spinner

  @envs[:current] = env
  
  @builder['env_box'].each do |item_box| 
    item_box.map {|item| item.class == Gtk::LinkButton}.each do |lb|
      if lb.name == env[:name] 
        lb.style_context.add_class('current_env');
      else
        lb.style_context.remove_class('current_env');
      end
    end
  end

  refresh_right_pane
  check_remote_repo

  # hide_spinner

end


def on_new_env_btn_clicked

  @new_env_dialog = @builder['new_env_dialog']
  @builder['new_env_name_entry'].text = "#{DEVELOPER.delete('.')}_"
  @new_env_dialog.show
  
end

def on_new_env_dialog_response(widget, response_id)

  @new_env_dialog.hide
  
  if response_id == Gtk::ResponseType::OK
    
    name = @builder['new_env_name_entry'].text

    if name.empty?
      show_message 'Your environment name is empty!'
      return
    end

    Dir.chdir BASEDIR do
      async_exec("new_env #{name}", true) 
    end
    
    refresh_all

  end
  
end

def on_delete_tbtn_clicked

  delete_environment

end


# =================== LOCAL REPO ====================

def on_file_selected(item_box, active, file)

  @files[file][:selected] = active

  item_box.each do |item| 
    if active
      item.style_context.add_class('current_env')
    else
      item.style_context.remove_class('current_env')
    end
  end
  
end

def on_file_choised(file, status)

  path = "#{BASEDIR}/#{@envs[:current][:name]}/#{file}".force_encoding('utf-8').encode('cp1251')

  if status == :untracked
    async_exec "#{EDITOR} '#{path}'"
  elsif status == :changed
    git_command "difftool -y \"#{path}\""
  end

end

def on_select_all_btn_clicked
  select_files(true)
end

def on_unselect_all_btn_clicked
  select_files(false)
end

def vlidate_commit?
  
  return unless choose_curent_env?

  if @builder['commit_entry'].text.empty?
    show_message 'Your commit message is empty!'
    return false
  end

  if @files.values.select { |attr| attr[:selected] }.empty?
    show_message "You don't choose files!"
    return false
  end

  true

end

def choose_curent_env?

  unless @envs[:current]
    show_message "You don't choose environments!"
    return false
  end

  true

end

def on_commit_btn_clicked

  return unless vlidate_commit?

  @files.select { |file, attr| attr[:selected] }.each_key do |file|
    git_command "add -A \"#{file.encode('cp1251')}\""
  end

  message = @builder['commit_entry'].text
  
  @close_tasks.each do |id|
    message << " #закрыто ##{id}"
  end

  git_command "commit -m \"#{message.encode('cp1251')}\""
  refresh_right_pane
  
  @builder['commit_entry'].text = ''

end

def on_refresh_local_repo_tbtn_clicked

  return unless choose_curent_env?

  git_status

end

def on_unpack_tbtn_clicked

  return unless choose_curent_env?
  
  run_script 'unpack'
  git_status

end

def on_pack_tbtn_clicked
  
  return unless choose_curent_env?

  run_script 'pack'
  git_status

end

def on_cmd_tbtn_clicked

  return unless choose_curent_env?

  Dir.chdir @envs[:current][:path]  do
    `start`
  end

end

def on_log_tbtn_clicked

  return unless choose_curent_env?

  Dir.chdir @envs[:current][:path]  do
    `gitk`
  end

end

# =================== REMOTE REPO ====================

# def on_check_remote_repo_tbtn_clicked

#   return unless choose_curent_env?
#   check_remote_repo

# end

def on_cmd_tbtn2_clicked
  
  on_cmd_tbtn_clicked

end

def on_pull_tbtn_clicked

  return unless choose_curent_env?
  run_script 'pull'
  check_remote_repo

end

def on_push_tbtn_clicked

  return unless choose_curent_env?
  run_script 'push'
  check_remote_repo

end

def on_notebook_switch_page
  
  check_remote_repo if @builder['notebook'].page == 1
  
end

# =================== TASKS ====================

def on_tasks_btn_clicked
  
  @tasks_wnd = @builder['tasks_wnd']
  refresh_tasks
  @tasks_wnd.show_all

end

def on_ok_tasks_btn_clicked
  @tasks_wnd.hide

  p @close_tasks
end

def on_cancel_tasks_btn_clicked
  @tasks_wnd.hide
  @close_tasks.clear
end

def on_new_task_tbtn_clicked
  Redmine.create_new_issue_in_browser
end

def on_refresh_tasks_tntn_clicked
  refresh_tasks
  @tasks_wnd.show_all
end

def on_task_selected (item_box, active, task)

  if active
    @close_tasks << task
  else
    @close_tasks.delete task
  end

end

def on_task_choised(id)
  Redmine.open_issue_in_browser(id)
end