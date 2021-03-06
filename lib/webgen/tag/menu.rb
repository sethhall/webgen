# -*- encoding: utf-8 -*-

module Webgen::Tag

  # Generates a menu that can be configured extensively.
  class Menu

    include Webgen::WebsiteAccess
    include Base

    # Special menu node class. It encapsulates the original node for later access.
    class MenuNode

      # Array of the child nodes.
      attr_reader :children

      # The parent node.
      attr_reader :parent

      # The encapsulated node.
      attr_reader :node

      # Set to +true+ if the menu node is in the tree of files.
      attr_writer :is_in_tree_of_files

      # Create a new menu node under +parent+ for the real node +node+.
      def initialize(parent, node)
        @parent = parent
        @node = node
        @children = []
      end

      # Return +true+ if the menu node is in the menu tree of only files.
      def is_in_tree_of_files?
        @is_in_tree_of_files
      end

      # Sort recursively all children of the node using the wrapped nodes.
      def sort!
        self.children.sort! {|a,b| a.node <=> b.node}
        self.children.each {|child| child.sort!}
        self
      end

      # Return the menu tree under the node as nested list of alcn values.
      def to_lcn_list
        self.children.inject([]) {|temp, n| temp << n.node.alcn; temp += ((t = n.to_lcn_list).empty? ? [] : [t]) }
      end

    end

    def initialize #:nodoc:
      website.blackboard.add_listener(:node_changed?, method(:node_changed?))
    end

    # Generate the menu.
    def call(tag, body, context)
      tree = specific_menu_tree_for(context.content_node)

      (context.dest_node.node_info[:tag_menu_menus] ||= {})[[@params.to_a.sort, context.content_node.alcn]] = (tree ? tree.to_lcn_list : nil)

      if !tree || tree.children.empty?
        ''
      elsif param('tag.menu.nested')
        create_output_nested(context, tree)
      else
        create_output_not_nested(context, tree)
      end
    end

    #########
    protected
    #########

    # Check if the menus for +node+ have changed.
    def node_changed?(node)
      return if !node.node_info[:tag_menu_menus]

      node.node_info[:tag_menu_menus].each do |(params, cn_alcn), cached_tree|
        cn = node.tree[cn_alcn]
        menu_tree = menu_tree_for_lang(cn.lang, cn.tree.root)

        set_params(params.to_hash)
        tree = build_specific_menu_tree(cn, menu_tree)
        tree_list = tree.to_lcn_list if tree
        set_params({})

        if (tree.nil? && !cached_tree.nil?) || (tree_list && tree_list != cached_tree) ||
            (tree_list && tree_list.flatten.any? do |alcn|
               (n = node.tree[alcn]) && (r = n.routing_node(cn.lang)) && r != node && r.meta_info_changed?
             end)
          node.flag(:dirty)
          break
        end
      end
    end

    # Wrapper method for returning the specific menu tree for +content_node+.
    def specific_menu_tree_for(content_node)
      tree = menu_tree_for_lang(content_node.lang, content_node.tree.root)
      if param('tag.menu.used_nodes') == 'fragments'
        @params['tag.menu.start_level'] = param('tag.menu.start_level') + content_node.level
      end
      build_specific_menu_tree(content_node, tree)
    end

    # Build a menu tree for +content_node+ from the tree +menu_node+.
    def build_specific_menu_tree(content_node, menu_node, level = 1)
      if menu_node.nil? \
        || level > param('tag.menu.max_levels') + param('tag.menu.start_level') - 1 \
        || ((level > param('tag.menu.min_levels') + param('tag.menu.start_level') - 1) \
             && (menu_node.node.level >= content_node.level \
                  || (param('tag.menu.show_current_subtree_only') && !content_node.in_subtree_of?(menu_node.node))
                 )
            ) \
        || (level == param('tag.menu.start_level') && !content_node.in_subtree_of?(menu_node.node))
        return nil
      end

      sub_menu_tree = MenuNode.new(nil, menu_node.node)
      menu_tree = MenuNode.new(nil, menu_node.node)
      menu_node.children.each do |child|
        next if param('tag.menu.used_nodes') == 'files' && !child.is_in_tree_of_files?
        menu_tree.children << (this_node = MenuNode.new(menu_tree, child.node))
        sub_node = child.children.length > 0 ? build_specific_menu_tree(content_node, child, level + 1) : nil
        sub_node.children.each {|n| this_node.children << n; sub_menu_tree.children << n} if sub_node
      end

      if level < param('tag.menu.start_level')
        sub_menu_tree
      else
        menu_tree
      end
    end

    # Create the nested HTML menu of the +tree+ using the provided +context+.
    def create_output_nested(context, tree, level = 1)
      out = "<ul>"
      tree.children.each do |child|
        menu = child.children.length > 0 ? create_output_nested(context, child, level + 1) : ''
        style, link = menu_item_details(context.dest_node, child.node, context.content_node.lang, level)

        out << "<li #{style}>#{link}"
        out << menu
        out << "</li>"
      end
      out << "</ul>"
      out
    end

    # Create the not nested HTML menu of the +tree+ using the provided +context+.
    def create_output_not_nested(context, tree, level = 1)
      submenu = ''
      out = "<ul>"
      tree.children.each do |child|
        submenu << (child.children.length > 0 ? create_output_not_nested(context, child, level + 1) : '')
        style, link = menu_item_details(context.dest_node, child.node, context.content_node.lang, level)

        out << "<li #{style}>#{link}</li>"
      end
      out << "</ul>"
      out << submenu
      out
    end

    # Return style information (node is selected, ...) and a link from +dest_node+ to +node+.
    def menu_item_details(dest_node, node, lang, level)
      styles = ['webgen-menu-level' + level.to_s]
      styles << 'webgen-menu-submenu' if node.is_directory? || (node.is_fragment? && node.children.length > 0)
      styles << 'webgen-menu-submenu-inhierarchy' if (node.is_directory? || (node.is_fragment? && node.children.length > 0)) &&
        dest_node.in_subtree_of?(node)
      styles << 'webgen-menu-item-selected' if node == dest_node
      style = "class=\"#{styles.join(' ')}\"" if styles.length > 0

      link = dest_node.link_to(node, :lang => lang)

      [style, link]
    end

    # Return the menu tree for the language +lang+.
    def menu_tree_for_lang(lang, root)
      menus = (website.cache.volatile[:menutrees] ||= {})
      unless menus[lang]
        menus[lang] = create_menu_tree(root, nil, lang)
        menus[lang].sort! if menus[lang]
      end
      menus[lang]
    end

    # Create and return a menu tree if at least one node is in the menu or +nil+ otherwise.
    def create_menu_tree(node, parent, lang)
      menu_node = MenuNode.new(parent, node)

      node.children.select do |child|
        child.lang == lang || child.lang.nil? || child.is_directory?
      end.each do |child|
        sub_node = create_menu_tree(child, menu_node, lang)
        menu_node.children << sub_node unless sub_node.nil?
      end
      menu_node.is_in_tree_of_files = (!node.is_fragment? && node['in_menu']) || menu_node.children.any? {|c| c.is_in_tree_of_files?}

      menu_node.children.empty? ? (node['in_menu'] ? menu_node : nil) : menu_node
    end

  end

end
