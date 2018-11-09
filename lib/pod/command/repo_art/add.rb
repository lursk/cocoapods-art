require "util/repo_util"
require "util/repo_manager"

module Pod
  class Command
    class RepoArt
      class Add < RepoArt
        UTIL = Pod::RepoArt::RepoUtil
        RepoManager = Pod::RepoArt::RepoManager

        self.summary = "Add a Specs repo from Artifactory."

        self.description = <<-DESC
          Retrieves the index from an Artifactory instance at 'URL' to the local spec repos-art
          directory at `~/.cocoapods/repos-art/'NAME'`.
        DESC

        self.arguments = [
          CLAide::Argument.new("NAME", true),
          CLAide::Argument.new("URL", true),
        ]

        def initialize(argv)
          init
          @name, @url = argv.shift_argument, argv.shift_argument
          @silent = argv.flag?("silent", false)
          super
        end

        def validate!
          super
          unless @name && @url
            help! "This command requires both a repo name and a url."
          end
        end

        def run
          begin
            UI.section("Retrieving index from `#{@url}` into local spec repo `#{@name}`") do
              RepoManager.create_repository(repo_dir_root, @name, @url)
            end
            UI.puts "Successfully added repo #{@name}".green unless @silent
          rescue => e
            raise e if !@silent
          end
        end
      end
    end
  end
end
