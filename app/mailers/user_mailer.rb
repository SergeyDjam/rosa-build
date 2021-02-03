class UserMailer < ActionMailer::Base
  add_template_helper ActivityFeedsHelper
  add_template_helper CommitHelper

  default from: "\"#{APP_CONFIG['project_name']}\" <#{APP_CONFIG['do-not-reply-email']}>"
  default_url_options.merge!(protocol: 'https') if APP_CONFIG['mailer_https_url']

  include Resque::Mailer # send email async

  def new_user_notification(user)
    @user = user
    mail(
      to:           email_with_name(user, user.email),
      subject:      I18n.t("notifications.subjects.new_user_notification",
      project_name: APP_CONFIG['project_name'])
    ) do |format|
      format.html
    end
  end

  def new_comment_notification(comment, user_id)
    @user, @comment = User.find(user_id), comment
    subject = @comment.issue_comment? ? subject_for_issue(@comment.commentable) :
      I18n.t('notifications.subjects.new_commit_comment_notification')
    mail(
      to:      email_with_name(@user, @user.email),
      subject: subject,
      from:    email_with_name(comment.user)
    ) do |format|
      format.html
    end
  end

  def new_issue_notification(issue_id, user_id)
    @user, @issue = User.find(user_id), Issue.find(issue_id)
    mail(
      to:      email_with_name(@user, @user.email),
      subject: subject_for_issue(@issue, true),
      from:    email_with_name(@issue.user)
    ) do |format|
      format.html
    end
  end

  def issue_assign_notification(issue, user)
    @issue = issue
    mail(
      to:      email_with_name(user, user.email),
      subject: subject_for_issue(@issue)
    ) do |format|
      format.html
    end
  end

  def build_list_notification(build_list, user)
    set_locale user
    @user, @build_list = user, build_list

    subject = "[№ #{build_list.id}] "
    subject << (build_list.project ? build_list.project.name_with_owner : t("layout.projects.unexisted_project"))
    subject << " - #{build_list.human_status} "
    subject << I18n.t("notifications.subjects.for_arch", arch: @build_list.arch.name)
    mail(
      to:      email_with_name(user, user.email),
      subject: subject,
      from:    email_with_name(build_list.publisher || build_list.user)
    ) do |format|
      format.html
    end
  end

  def metadata_regeneration_notification(platform, user)
    set_locale user
    @user, @platform = user, platform

    subject = "[#{platform.name}] "
    subject << I18n.t("notifications.subjects.metadata_regeneration", status: I18n.t("layout.regeneration_statuses.last_regenerated_statuses.#{platform.human_regeneration_status}"))
    mail(
      to:      email_with_name(user, user.email),
      subject: subject,
      from:    email_with_name(platform.owner)
    ) do |format|
      format.html
    end
  end

  def git_delete_branch_notification(user, options)
    set_locale user
    mail(
      to:      user.email,
      subject: I18n.t('notifications.subjects.update_code', project_name: "#{options[:project_owner]}/#{options[:project_name]}")
    ) do |format|
      format.html { render 'git_delete_branch_notification', locals: options }
    end
  end

  def git_new_push_notification(user, options)
    set_locale user
    mail(
      to:      user.email,
      subject: I18n.t('notifications.subjects.update_code', project_name: "#{options[:project_owner]}/#{options[:project_name]}")
    ) do |format|
      format.html { render 'git_new_push_notification', locals: options }
    end
  end

  protected

  def set_locale(user)
    I18n.locale = user.language if user.language
  end

  def email_with_name(user, email = APP_CONFIG['do-not-reply-email'])
    "\"#{user.user_appeal}\" <#{email}>"
  end

  def subject_for_issue(issue, new_issue = false)
    subject = new_issue ? '' : 'Re: '
    subject << "[#{issue.project.name}] #{issue.title} (##{issue.serial_id})"
  end
end
