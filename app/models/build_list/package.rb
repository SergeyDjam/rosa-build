class BuildList::Package < ActiveRecord::Base
  PACKAGE_TYPES = %w(source binary)

  belongs_to :build_list, touch: true
  belongs_to :project
  belongs_to :platform

  serialize :dependent_packages, Array

  validates :build_list, :build_list_id, :project, :project_id,
            :platform, :platform_id, :fullname,
            :package_type, :name, :release, :version,
            presence: true
  validates :package_type, inclusion: PACKAGE_TYPES
  validates :sha1, presence: true, if: Proc.new { |p| p.build_list.new_core? }

  default_scope { order("lower(#{table_name}.name) ASC, length(#{table_name}.name) ASC") }

  # Fetches only actual (last publised) packages.
  scope :actual,          ->           { where(actual: true) }
  scope :by_platform,     ->(platform) { where(platform_id: platform) }
  scope :by_name,         ->(name)     { where(name: name) }
  scope :by_package_type, ->(type)     { where(package_type: type) }
  scope :like_name,       ->(name)     { where("#{table_name}.name ILIKE ?", "%#{name}%") if name.present? }

  before_create :set_epoch

  def assignee
    project.maintainer
  end

  # Comparison between versions
  # @param [BuildList::Package] other
  # @return [Number] -1 if +other+ is greater than, 0 if +other+ is equal to,
  #   and +1 if other is less than version.
  def rpmvercmp(other)
    RPM.compareVREs to_vre_epoch_zero, other.to_vre_epoch_zero
  end

  def self.by_repository(repository, &block)
    # find_each will batch the results instead of getting all in one go
    actual.where(
      build_lists: {save_to_repository_id: repository}
    ).joins(build_list: :save_to_repository).includes(project: :maintainer).find_each do |package|
      yield package
    end
  end

  # Public: Set dependent_packages.
  def dependent_packages=(v)
    v = v.to_s.split(/\s/).select(&:present?) if v.is_a?(String)
    write_attribute :dependent_packages, v
  end

  protected

  def set_epoch
    self.epoch = nil if epoch.blank? || epoch == 0
  end

  # String representation in the form "e:v-r"
  # @return [String]
  # @note The epoch is included always. As 0 if not present
  def to_vre_epoch_zero
    res = []
    if epoch.present?
      res << epoch.to_s
    else
      res << '0'
    end
    if version.present?
      res << version.to_s
    else
      res << ''
    end
    if release.present?
      res << release.to_s
    else
      res << ''
    end
    res
  end

end
