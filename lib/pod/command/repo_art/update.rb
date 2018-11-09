require "util/repo_util"
require "util/repo_manager"

module Pod
  class Command
    class RepoArt
      class Update < RepoArt
        UTIL = Pod::RepoArt::RepoUtil
        RepoManager = Pod::RepoArt::RepoManager

        self.summary = "Update an Artifactory-backed Specs repo."

        self.description = <<-DESC
          Updates the Artifactory-backed spec-repo `NAME`.
        DESC

        def self.options
          [
            ["--prune", "Prunes entries which do not exist in the remote this index was pulled from."],
          ].concat(super)
        end

        self.arguments = [
          CLAide::Argument.new("NAME", true),
        ]

        def initialize(argv)
          @name = argv.shift_argument
          @prune = argv.flag?("prune", false)
          super
        end

        def validate!
          super
          unless @name
            help! "This command requires a repo name to run."
          end
        end

        def run
          update(@name, true)
        end

        private

        # Update command for Artifactory sources.
        #
        # @param  [String] source_name name
        #
        def update(source_name = nil, show_output = false)
          if source_name
            sources = [UTIL.get_art_repo(source_name)]
          else
            sources = UTIL.get_art_repos()
          end

          sources.each do |source|
            UI.section "Updating spec repo `#{source.name}`" do
              Dir.chdir(source.path) do
                begin
                  # TODO HEAD to api/updateTime
                  # TODO unless .lastupdated >= api/updateTime do
                  # TODO Until we support delta downloads, update is actually add if not currently up tp date
                  url = UTIL.get_art_url(source.path)
                  if @prune
                    hard_update(source.path, source.name, url)
                  else
                    soft_update(source.path, source.name, url)
                  end
                  UI.puts "Successfully updated repo #{source.name}".green if show_output && !config.verbose?
                rescue => e
                  UI.warn "Unable to update repo `#{source.name}`: #{e.message}"
                end
              end
            end
          end
        end

        # Performs a 'soft' update which appends any changes from the remote without deleting out-of-sync entries
        #
        def soft_update(path, name, url)
          RepoManager.update_repository_soft(path, name, url)
        end

        # Performs a 'hard' update which prunes all index entries which are not sync with the remote (override)
        #
        def hard_update(path, name, url)
          UI.puts path
          RepoManager.update_repository_hard(path, name, url)
        end
      end
    end
  end
end
