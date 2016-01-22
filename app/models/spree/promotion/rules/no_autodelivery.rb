module Spree
  class Promotion
    module Rules
      class NoAutodelivery < PromotionRule

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})   #line_item is target
          return false if order.line_items.any? {|l| l[:auto_delivery]}
          return true
        end

        def actionable?(line_item)
           false
        end

      end
    end
  end
end
