# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Handles directory source paths.
  class Directory

    include Base
    include Webgen::WebsiteAccess

    def initialize # :nodoc:
      website.blackboard.add_service(:create_directories, method(:create_directories))
    end

    # Recursively create the directories specified in +dirname+ under +parent+ (a leading slash is
    # ignored). The path +path+ is the path that lead to the creation of these directories.
    def create_directories(parent, dirname, path)
      dirname.sub(/^\//, '').split('/').each do |dir|
        dir_path = Webgen::Path.new(File.join(parent.alcn, dir, '/'), path)
        nodes = website.blackboard.invoke(:create_nodes, dir_path, self) do |dir_path|
          node_exists?(dir_path) || create_node(dir_path)
        end
        parent = nodes.first
      end
      parent
    end

  end

end
