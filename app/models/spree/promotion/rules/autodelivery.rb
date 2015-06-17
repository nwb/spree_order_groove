module Spree
  class Promotion
    module Rules
      class Autodelivery < PromotionRule

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})   #line_item is target

          order.line_items.any? {|l| l[:auto_delivery]}
        end

        def actionable?(line_item)

          line_item.auto_delivery
        end

      end
    end
  end
end
