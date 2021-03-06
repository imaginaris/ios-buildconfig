require 'fileutils'
require 'yaml'
require 'uri'

module Fastlane
  module Actions
    class GhPagesAction < Action
      def self.run(params)
        github_token = params[:github_token]
        ghpages_url = params[:ghpages_url]

        UI.message("Generating documentation")
        # Check necessary input data
        UI.user_error!("Missing `_versions` file") unless File.exists?("_versions")
        UI.user_error!("Missing `.jazzy.yaml` file") unless File.exists?(".jazzy.yaml")
        module_version = YAML.load(File.read(".jazzy.yaml"))["module_version"]
        UI.user_error!("Missing `module_version` parameter in .jazzy.yaml file") unless module_version != nil

        # Prepare environment
        FileUtils.rm_rf("artifacts/docs")
        sh "git clone --single-branch --branch gh-pages #{ghpages_url} artifacts/docs"
        FileUtils.rm_rf("artifacts/docs/#{module_version}")

        # Download theme and generate docs
        sh "svn export https://github.com/rakutentech/ios-buildconfig/trunk/jazzy_themes jazzy_themes --force"
        sh "bundle exec jazzy --output artifacts/docs/#{module_version} --theme jazzy_themes/apple_versions"

        # Generate html files
        versions_string = File.readlines("_versions").map{|line| "\"#{line.strip}\""}.join(",")
        versions_js = "const Versions = [" + versions_string + "];"
        File.open("artifacts/docs/versions.js", "w") { |f| f.write versions_js }
        File.open("artifacts/docs/index.html", "w") { |f| f.write "<html><head><meta http-equiv=\"refresh\" content=\"0; URL=#{module_version}/index.html\" /></head></html>" }

        UI.message("Deploying documentation")
        # Deploy to GitHub Pages
        git_cmd_config = "--git-dir=artifacts/docs/.git --work-tree=artifacts/docs/"
        sh "git #{git_cmd_config} add . -f"
        sh "git #{git_cmd_config} commit -m \"Deploy Jazzy docs for version #{module_version}\""

        gh_host = URI.parse(ghpages_url).host
        sh "git #{git_cmd_config} config url.\"https://x-token-auth:#{github_token}@#{gh_host}\".InsteadOf https://#{gh_host}"
        sh "git #{git_cmd_config} push origin gh-pages"

        # Cleanup
        FileUtils.rm_rf("jazzy_themes")
      end

      def self.description
        "Generate Jazzy documentation for sdk module and publish it to GitHub Pages"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :ghpages_url,
                                       description: "Repository URL to store generated documentation (gh-pages branch)"),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       description: "GitHub API token for publising generated documentation")
        ]
      end

      def self.output
      end

      def self.authors
        ["rem"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end

# vim:syntax=ruby:et:sts=2:sw=2:ts=2:ff=unix: