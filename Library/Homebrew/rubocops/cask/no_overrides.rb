# typed: true
# frozen_string_literal: true

module RuboCop
  module Cop
    module Cask
      class NoOverrides < Base
        extend T::Sig
        include CaskHelp

        ON_SYSTEM_METHODS = RuboCop::Cask::Constants::ON_SYSTEM_METHODS
        MESSAGE = <<~EOS
          Do not use a top-level `%<stanza>s` stanza as the default. Add it to an `on_{system}` block instead.
          Use `:or_older` or `:or_newer` to specify a range of macOS versions.
        EOS

        def on_cask(cask_block)
          cask_stanzas = cask_block.toplevel_stanzas

          # Skip if there are no `on_*` blocks.
          return unless (on_blocks = cask_stanzas.select { |s| ON_SYSTEM_METHODS.include?(s.stanza_name) }).any?

          stanzas_in_blocks = on_system_stanzas(on_blocks)

          cask_stanzas.each do |stanza|
            # Skip if the stanza is itself an `on_*` block.
            next if ON_SYSTEM_METHODS.include?(stanza.stanza_name)
            # Skip if the stanza outside of a block is not also in an `on_*` block.
            next unless stanzas_in_blocks.include?(stanza.stanza_name)

            add_offense(stanza.source_range, message: format(MESSAGE, stanza: stanza.stanza_name))
          end
        end

        def on_system_stanzas(on_system)
          names = Set.new
          method_nodes = on_system.map(&:method_node)
          method_nodes.each do |node|
            next unless node.block_type?

            node.child_nodes.each do |child|
              child.each_node(:send) do |send_node|
                # Skip (nested) livecheck blocks as its `url` is different to a download `url`.
                next if send_node.method_name == :livecheck || inside_livecheck_block?(send_node)
                # Skip string interpolations (`:send` inside `:begin` inside `:dstr`).
                next if send_node.parent.begin_type? && send_node.parent.parent.dstr_type?
                next if ON_SYSTEM_METHODS.include?(send_node.method_name)

                names.add(send_node.method_name)
              end
            end
          end
          names
        end

        def inside_livecheck_block?(node)
          single_stanza_livecheck_block?(node) || multi_stanza_livecheck_block?(node)
        end

        def single_stanza_livecheck_block?(node)
          node.parent.block_type? && node.parent.method_name == :livecheck
        end

        def multi_stanza_livecheck_block?(node)
          grandparent_node = node.parent.parent
          node.parent.begin_type? && grandparent_node.block_type? && grandparent_node.method_name == :livecheck
        end
      end
    end
  end
end
