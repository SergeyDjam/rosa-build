module AbfWorkerService
  class Base

    REDIS_MAIN_KEY = 'abf-worker::build-lists-publish-task-manager::'

    %w(
      PROJECTS_FOR_CLEANUP
      LOCKED_PROJECTS_FOR_CLEANUP
      LOCKED_BUILD_LISTS
      PACKAGES_FOR_CLEANUP
      REP_AND_PLS_OF_BUILD_LISTS_FOR_CLEANUP_FROM_TESTING
      BUILD_LISTS_FOR_CLEANUP_FROM_TESTING
    ).each do |kind|
      const_set kind, "#{REDIS_MAIN_KEY}#{kind.downcase.gsub('_', '-')}"
    end

    def self.cleanup_completed(projects_for_cleanup)
      $redis.with do |r|
        r.multi do
          projects_for_cleanup.each do |key|
            r.lrem LOCKED_PROJECTS_FOR_CLEANUP, 0, key
            r.hdel PACKAGES_FOR_CLEANUP, key
          end
        end
      end
    end

    def self.cleanup_failed(projects_for_cleanup)
      $redis.with do |r|
        r.multi do
          projects_for_cleanup.each do |key|
            r.lrem LOCKED_PROJECTS_FOR_CLEANUP, 0, key
            r.lpush PROJECTS_FOR_CLEANUP, key
          end
        end
      end
    end

    def self.cleanup_packages_from_testing(platform_id, repository_id, *build_lists)
      return if build_lists.blank?
      rep_pl = "#{repository_id}-#{platform_id}"
      key = "#{BUILD_LISTS_FOR_CLEANUP_FROM_TESTING}-#{rep_pl}"
      $redis.with do |r|
        r.sadd REP_AND_PLS_OF_BUILD_LISTS_FOR_CLEANUP_FROM_TESTING, rep_pl
        r.sadd key, build_lists
      end
    end

    protected

    def packages_structure
      structure = {sources: [], binaries: {}}
      Arch.pluck(:name).each{ |name| structure[:binaries][name.to_sym] = [] }
      structure
    end

    def fill_packages(bl, results_map, field = :sha1)
      results_map[:sources] |= bl.packages.by_package_type('source').pluck(field).compact if field != :sha1

      binaries  = bl.packages.by_package_type('binary').pluck(field).compact
      arch      = bl.arch.name.to_sym
      results_map[:binaries][arch] |= binaries
      # Publish/remove i686 RHEL packages into/from x86_64
      if arch == :i586 && bl.build_for_platform.distrib_type == 'rhel' && bl.project.publish_i686_into_x86_64?
        results_map[:binaries][:x86_64] |= binaries
      end
    end

    def filter_build_lists_without_packages(*build_lists)
      ids = []
      build_lists = build_lists.flatten.select do |build_list|
        sha1 = build_list.packages.pluck(:sha1).find do |sha1|
          !FileStoreService::File.new(sha1: sha1).exist?
        end
        if sha1.present?
          ids << build_list.id
          false
        else
          true
        end
      end

      BuildList.where(id: ids).update_all(status: BuildList::PACKAGES_FAIL)

      build_lists
    end

  end
end