class Projects::Git::TreesController < Projects::Git::BaseController

  skip_before_action :set_branch_and_tree,      only: [:archive, :get_sha1_of_archive]
  skip_before_action :set_treeish_and_path,     only: [:archive, :get_sha1_of_archive]
  before_action      :redirect_to_project,      only: :show
  before_action      :resolve_treeish,          only: [:branch, :destroy]

  # skip_authorize_resource :project,                 only: [:destroy, :restore_branch, :create]
  before_action -> { authorize(@project, :show?)  },  only: [:show, :archive, :tags, :branches, :get_sha1_of_archive]

  def show
    unless request.xhr?
      render('empty') and return if @project.is_empty?
      @tree = @tree / @path if @path.present?
      @commit = @branch.present? ? @branch.commit() : @project.repo.log(@treeish, @path, max_count: 1).first
      raise Grit::NoSuchPathError unless @commit
    else
      @tree = @tree / @path if @path.present?
    end
  end

  def archive
    format, @treeish = params[:format], params[:treeish]
    raise Grit::NoSuchPathError unless  @treeish =~ /^#{@project.name}-/ &&
                                        @treeish !~ /[\s]+/ &&
                                        format =~ /\A(zip|tar\.gz)\z/
    @treeish.gsub!(/^#{@project.name}-/, '')
    @commit = @project.repo.commits(@treeish, 1).first
    raise Grit::NoSuchPathError unless @commit
    tag     = @project.repo.tags.find{ |t| t.name == @treeish }
    sha1    = @project.get_project_tag_sha1(tag, format) if tag

    if sha1.present?
      redirect_to "#{APP_CONFIG['file_store_url']}/api/v1/file_stores/#{sha1}"
    else
      archive = @project.archive_by_treeish_and_format @treeish, format
      send_file archive[:path], disposition: 'attachment', type: "application/#{format == 'zip' ? 'zip' : 'x-tar-gz'}", filename: archive[:fullname]
    end
  end

  def get_sha1_of_archive
    format, @treeish = params[:format], params[:treeish]
    raise Grit::NoSuchPathError unless  @treeish =~ /^#{@project.name}-/ &&
                                        @treeish !~ /[\s]+/ &&
                                        format =~ /\A(zip|tar\.gz)\z/
    @treeish.gsub!(/^#{@project.name}-/, '')
    @commit = @project.repo.commits(@treeish, 1).first
    raise Grit::NoSuchPathError unless @commit
    tag     = @project.repo.tags.find{ |t| t.name == @treeish }
    sha1    = @project.get_project_tag_sha1(tag, format) if tag
    sha1    ||= ''

    render plain: sha1
  end

  def tags
    if request.xhr?
      @refs = @project.repo.tags.select{ |t| t.commit }.sort_by(&:name).reverse
      render :refs_list
    else
      respond_to do |format|
        format.json { render nothing: true, status: 422 }
        format.html
      end
    end
  end

  def restore_branch
    authorize @project, :write?
    status = @project.create_branch(@treeish, params[:sha], current_user) ? 200 : 422
    render nothing: true, status: status
  end

  def create
    authorize @project, :write?
    status = @project.create_branch(params[:new_ref], params[:from_ref], current_user) ? 200 : 422
    render nothing: true, status: status
  end

  def destroy
    authorize @project, :write?
    status = @branch && @project.delete_branch(@branch, current_user) ? 200 : 422
    render nothing: true, status: status
  end

  def branches
    if request.xhr?
      @refs = @project.repo.branches.sort_by(&:name)
      render :refs_list
    else
      respond_to do |format|
        format.json { render nothing: true, status: 422 }
        format.html
      end
    end
  end

  protected

  def resolve_treeish
    raise Grit::NoSuchPathError if params[:treeish] != @branch.try(:name)
  end

  def redirect_to_project
    if params[:treeish] == @project.resolve_default_branch && params[:path].blank? && !request.xhr?
      redirect_to @project
    end
  end

end
