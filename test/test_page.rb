# -*- encoding: utf-8 -*-

require 'test/unit'
require 'webgen/page'

class TestBlock < Test::Unit::TestCase

  def test_render
    block = Webgen::Page::Block.new('content', 'some content', {'pipeline' => 'test'})
    context = {:processors => {}}
    assert_raise(RuntimeError) { block.render(context) }
    context[:processors]['test'] = lambda {|context| context[:content] = context[:content].reverse + context[:block].name }
    assert_equal('some content'.reverse + 'content', block.render(context)[:content])
  end

end

class TestPage < Test::Unit::TestCase

  VALID = <<EOF
# with more blocks
- in: |
    ---
    key: value
    ---
    block1
    --- 
      block2  
    ---  name:block3
    ---  name:block4
    yes
  meta_info: {key: value}
  blocks:
    - name: content
      content: "block1"
    - name: block2
      content: "  block2  "
    - name: block3
      content: ''
    - name: block4
      content: "yes\\n"

# empty file
- in: ""
  meta_info: {}
  blocks:
    - name: content
      content: ''

# without meta info
- in: "hallo"
  meta_info: {}
  blocks:
    - name: content
      content: "hallo"

# with empty block
- in: |
    --- 
    key: value

    ---

  meta_info: {key: value}
  blocks:
    - name: content
      content: ''

# with only meta information, no blocks
- in: |
    ---
    key: value

  meta_info: {key: value}
  blocks:
    - name: content
      content: ''

# block with escaped ---
- in: |
    before
    \\--- in
    after
  meta_info: {}
  blocks:
    - name: content
      content: "before\\n--- in\\nafter\\n"

# no meta info, starting with block with name
- in: |
    --- name:block1
  meta_info: {}
  blocks:
    - name: block1
      content: ''

# named block and block with other options
- in: |
    --- name:block
    content doing -
    with?: with some things

    --- other:options test1:true test2:false test3:542 pipeline:
  meta_info: {}
  blocks:
    - name: block
      content: "content doing -\\nwith?: with some things\\n"
    - name: block2
      content: ''
      options: {other: options, test1: true, test2: false, test3: 542, pipeline: ~}

# block with seemingly block start line it
- in: |
    --- name:block
    content
    ----------- some block start???
    things
  meta_info: {}
  blocks:
    - name: block
      content: "content\\n----------- some block start???\\nthings\\n"

# last block ending with no whitespace at tend
- in: "--- name:block\\nblock\\n\\n--- name:block1\\ncontent"
  meta_info: {}
  blocks:
    - name: block
      content: "block\\n"
    - name: block1
      content: "content"

# last block ending with empty line
- in: "content\\n\\n"
  meta_info: {}
  blocks:
    - name: content
      content: "content\\n\\n"

EOF

  INVALID_MI=<<EOF
# invalid meta info: none specified
- "---\\n---"

# invalid meta info: no hash
- |
  ---
  doit
  ---
  asdf kadsfakl

# invalid meta info: not in yaml format
- |
  ---
  - doit
  : * [ }
  ---
  asdf kadsfakl
EOF

  INVALID_BLOCKS=<<EOF
# two blocks with same name
- |
  aasdf
  asdfdf
  --- name:name
  asdkf dsaf
  --- name:name
  asdf adsf

# invalid format
- |
  asdfasd
  dfdf
  --- name, incorrect_format
  lsldf
EOF

  def test_invalid_pagefiles
    testdata = YAML::load(INVALID_MI)
    testdata.each_with_index do |data, index|
      assert_raise(Webgen::Page::FormatError, "test mi item #{index}") { Webgen::Page.from_data(data) }
      assert_raise(Webgen::Page::FormatError, "test mi item #{index}") { Webgen::Page.meta_info_from_data(data) }
    end
    testdata = YAML::load(INVALID_BLOCKS)
    testdata.each_with_index do |data, index|
      assert_raise(Webgen::Page::FormatError, "test blocks item #{index}") { Webgen::Page.from_data(data) }
    end
  end

  def test_valid_pagefiles
    YAML::load(VALID).each_with_index do |data, oindex|
      mi = Webgen::Page.meta_info_from_data(data['in'])
      assert_equal(data['meta_info'], mi, "test item #{oindex} - meta info directly")
      d = Webgen::Page.from_data(data['in'])
      assert_equal(data['meta_info'], d.meta_info, "test item #{oindex} - meta info all")
      assert_equal(data['blocks'].length*2, d.blocks.length)
      data['blocks'].each_with_index do |b, index|
        index += 1
        assert_equal(b['name'], d.blocks[index].name, "test item #{oindex} - name")
        assert_equal(b['content'], d.blocks[index].content, "test item #{oindex} - content")
        assert_equal(b['options'] || {}, d.blocks[index].options, "test item #{oindex} - options")
        assert_same(d.blocks[index], d.blocks[b['name']])
      end
    end
  end

  def test_default_values
    valid = YAML::load(VALID)
    d = Webgen::Page.from_data(valid[0]['in'], 'blocks' => {1 => { 'name' => 'other1'}, 2 => { 'name' => 'block7'}})
    assert_equal({'key' => 'value'}, d.meta_info)
    assert_equal('other1', d.blocks[1].name)
    assert_equal('block7', d.blocks[2].name)
  end

  def test_eol_encodings
    d = Webgen::Page.from_data("---\ntitle: test\r---\r\ncontent")
    assert_equal({'title' => 'test'}, d.meta_info)
    assert_equal('content', d.blocks['content'].content)
  end

  def test_meta_info_dupped
    mi = {'key' => 'value'}
    d = Webgen::Page.from_data("---\ntitle: test\n---\ncontent", mi)
    assert_equal({'title' => 'test', 'key' => 'value'}, d.meta_info)
    assert_not_same(mi, d.meta_info)
    d = Webgen::Page.from_data("content", mi)
    assert_equal({'key' => 'value'}, d.meta_info)
    assert_not_same(mi, d.meta_info)
  end

end
