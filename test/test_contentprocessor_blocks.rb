# -*- encoding: utf-8 -*-

require 'test/unit'
require 'helper'
require 'webgen/tree'
require 'webgen/page'
require 'webgen/contentprocessor'

class TestContentProcessorBlocks < Test::Unit::TestCase

  include Test::WebsiteHelper

  def test_call_and_render_node
    obj = Webgen::ContentProcessor::Blocks.new
    root = Webgen::Node.new(Webgen::Tree.new.dummy_root, '/', '/')
    node = Webgen::Node.new(root, 'test', 'test')
    node.node_info[:page] = Webgen::Page.from_data("--- name:content\ndata\n--- name:other\nother")
    template = Webgen::Node.new(root, 'template', 'template')
    template.node_info[:page] = Webgen::Page.from_data("--- name:content pipeline:blocks\nbefore<webgen:block name='content' />after")
    processors = { 'blocks' => obj }

    context = Webgen::Context.new(:chain => [node], :processors => processors)
    context.content = '<webgen:block name="content" /><webgen:block name="content" chain="template;test" />'
    obj.call(context)
    assert_equal('databeforedataafter', context.content)
    assert_equal(Set.new([node.alcn, template.alcn]), node.node_info[:used_nodes])

    context.content = '<webgen:block name="content" node="next" /><webgen:block name="content" chain="template;test" />'
    obj.call(context)
    assert_equal('databeforedataafter', context.content)

    context.content = '<webgen:block name="nothing"/>'
    assert_raise(RuntimeError) { obj.call(context) }

    context.content = '<webgen:block name="content" chain="invalid" /><webgen:block name="content" />'
    node.node_info[:used_nodes] = Set.new
    context[:chain] = [node, template, node]
    context.dest_node.unflag(:dirty)
    obj.call(context)
    assert_equal('beforedataafter', context.content)
    assert_equal(Set.new([template.alcn, node.alcn]), node.node_info[:used_nodes])
    assert(context.dest_node.flagged?(:dirty))

    context.content = 'bef<webgen:block name="other" chain="template;test" notfound="ignore" />aft'
    obj.call(context)
    assert_equal('befaft', context.content)

    context.content = '<webgen:block name="other" chain="template" node="first" />'
    assert_raise(RuntimeError) { obj.call(context) }

    context.content = '<webgen:block name="other" chain="template;test" node="first" />'
    obj.call(context)
    assert_equal('other', context.content)

    context.content = '<webgen:block name="other" chain="test" node="first" />'
    obj.call(context)
    assert_equal('other', context.content)

    context.content = '<webgen:block name="invalid" node="first" notfound="ignore" /><webgen:block name="content" />'
    obj.call(context)
    assert_equal('beforedataafter', context.content)

    context[:chain] = [node, template]
    context.content = '<webgen:block name="other" node="current" />'
    obj.call(context)
    assert_equal('other', context.content)

    context.content = '<webgen:block name="other" node="current" chain="template"/>'
    obj.call(context)
    assert_equal('other', context.content)

    assert_equal('other', obj.render_block(context, :chain => [template], :name => 'other', :node => 'current'))
    assert_equal('beforedataafter', obj.render_block(context, :chain => [template, node], :name => 'content', :node => 'first'))
  end

end
