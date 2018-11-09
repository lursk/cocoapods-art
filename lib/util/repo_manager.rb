require "util/repo_util"

module Pod
  class RepoArt
    class RepoManager
      UTIL = Pod::RepoArt::RepoUtil

      def self.repository_exists(repo_path)
        File.exist?("#{repo_path}")
      end

      def self.update_repository_soft(repo_path, name, url)
        downloader = Pod::Downloader::Http.new("#{repo_path}", "#{url}/index/fetchIndex", :type => "tgz", :indexDownload => true)
        downloader.download
        UTIL.cleanup_index_download("#{repo_path}")
        UTIL.del_redundant_spec_dir("#{repo_path}/Specs/Specs")
        system "cd '#{repo_path}' && git add . && git commit -m 'Artifactory repo update specs'"
      end

      def self.update_repository_hard(repo_path, name, url)
        repo_art_path = Pod::RepoArt::RepoUtil.get_repos_art_dir()
        isAddedToRemotes = repo_path.start_with?(repo_art_path)
        repos_path = "#{Pod::Config.instance.home_dir}/repos/#{name}"

        begin
          repo_path_update_tmp = "#{repo_path}_update_tmp"
          system("mv", repo_path.to_s, repo_path_update_tmp)
          if isAddedToRemotes
            repos_path_update_tmp = "#{repos_path}_update_tmp"
            system("mv", repos_path.to_s, repos_path_update_tmp)
          end

          Pod::RepoArt::RepoManager.create_repository(repo_path, name, url)

          FileUtils.remove_entry_secure(repo_path_update_tmp, :force => true)
          if isAddedToRemotes
            FileUtils.remove_entry_secure(repos_path_update_tmp, :force => true)
          end
        rescue => e
          FileUtils.remove_entry_secure(repo_path.to_s, :force => true)
          system("mv", repo_path_update_tmp, repo_path.to_s)
          if isAddedToRemotes
            system("mv", repos_path_update_tmp, repos_path.to_s)
          end
          raise Informative, "Error getting the index from Artifactory at: '#{url}' : #{e.message}"
        end
      end

      # Creates repository with name and url at given path
      #
      # @param [String] repo_path - path to the repository
      # @param [String] name - repository name
      # @param [String] url - repository url
      #
      def self.create_repository(repo_path, name, url)
        repo_art_path = Pod::RepoArt::RepoUtil.get_repos_art_dir()
        addToRemotes = repo_path.start_with?(repo_art_path)

        # Check if a repo with the same name under repos/ already exists
        repos_path = "#{Pod::Config.instance.home_dir}/repos"
        raise Informative, "Path repos_path/#{name} already exists - remove it first, " \
              "or run 'pod repo-art update #{name}' to update it" if addToRemotes && File.exist?("#{repos_path}/#{@name}")

        # Check if a repo with the same name under repo-art/ already exists
        repo_dir_root = "#{repo_path}/#{name}"
        raise Informative, "Path #{repo_dir_root} already exists - remove it first, " \
              "or run 'pod repo-art update #{name}' to update it" if File.exist?(repo_dir_root)

        FileUtils::mkdir_p repo_dir_root

        repo_dir_specs = "#{repo_path}/Specs"
        begin
          downloader = Pod::Downloader::Http.new(repo_dir_specs, "#{url}/index/fetchIndex", :type => "tgz", :indexDownload => true)
          downloader.download
        rescue => e
          FileUtils.remove_entry_secure(repo_path, :force => true)
          raise Informative, "Error getting the index from Artifactory at: '#{url}' : #{e.message}"
        end

        begin
          UTIL.cleanup_index_download(repo_dir_specs)
          UTIL.del_redundant_spec_dir("#{repo_dir_specs}/Specs")
        rescue => e
          UI.warn("Failed cleaning up temp files in #{repo_dir_specs}")
        end

        begin
          artpodrc_path = create_artpodrc_file(repo_dir_root)
        rescue => e
          raise Informative, "Cannot create file '#{artpodrc_path}' because : #{e.message}." \
                "- your Artifactory-backed Specs repo will not work correctly without it!"
        end
        # Create a local git repository in the newly added Artifactory local repo
        system "cd '#{repo_path}' && git init && git add . && git commit -m 'Artifactory repo init'"

        # Create local repo under repos/ which is a remote for the new local git repository
        if addToRemotes
          repos_path = "#{Pod::Config.instance.home_dir}/repos"
          system "cd '#{repos_path}' && git clone file://#{repo_path}"
        end
      end

      # Removes repository at given path
      #
      # @param [String] repo_path path to the repository
      #
      def self.remove_repository(repo_path)
        FileUtils.rm_rf(repo_dir_root)
      end

      private

      # Creates the .artpodrc file which contains the repository's url in the root of the Spec repo
      #
      # @param [String] repo_dir_root root of the Spec repo
      #
      def self.create_artpodrc_file(repo_dir_root)
        artpodrc_path = "#{repo_dir_root}/.artpodrc"
        artpodrc = File.new(artpodrc_path, "wb")
        artpodrc << @url
        artpodrc.close
        artpodrc_path
      end
    end
  end
end
