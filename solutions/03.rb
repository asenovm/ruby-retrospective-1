require 'bigdecimal'
require 'bigdecimal/util'
#TODO refactor/cleanup + use modules instead of utils if there's time
class Product
  attr_reader :name, :price, :discount
  def initialize(name, price, discount)
    Validate.product_name_length(name)
    Validate.product_price(price)
    @name = name
    @price = price.to_d
    @discount = DiscountUtil.get_discount_instance(discount)
  end

  #returns the total amount of money the user should pay for the items bought
  def calculate_product_total(items_bought)
    result = items_bought * @price
    if @discount
      result -= @discount.apply(self, items_bought)
    end
    result 
  end
end

#kinda like a factory, but not really
class DiscountUtil
  def self.get_discount_instance(discount_hash)
    if discount_hash[:get_one_free]
      OneFreeDiscount.new(discount_hash[:get_one_free])
    elsif discount_hash[:package]
      PackageDiscount.new(discount_hash[:package])
    elsif discount_hash[:threshold]
      AmountDiscount.new(discount_hash[:threshold])
    else
      nil
    end
  end
end

class BaseDiscount
  def apply(product, items_bought)
    raise "This should be overriden"
  end
end

class OneFreeDiscount < BaseDiscount
  attr_reader :item_at, :free_items
  def initialize(item_at_is_free)
    @item_at = item_at_is_free
  end

  def apply(product, items_bought)
    @free_items = items_bought / @item_at
    res = @free_items * product.price
    while @free_items / @item_at > 0
      @free_items = @free_items / @item_at
    end
    res
  end
end

class PackageDiscount < BaseDiscount
  attr_reader :percent, :discount_for_every
  def initialize(package_discount_hash)
   package_discount_hash.each do |key, value|
    @discount_for_every = key
    @percent = value
   end
  end

  #returns the amount of the discount
  def apply(product, items_bought)
    times_discount_applied = items_bought / @discount_for_every
    percent = BigDecimal((@percent/100.to_f).to_s)
    discounted_items = (times_discount_applied * @discount_for_every).to_s.to_d
    percent * discounted_items * product.price
  end
end

class AmountDiscount < BaseDiscount
  attr_reader :threshold, :percent
  def initialize(amount_discount_hash)
    amount_discount_hash.each do |key, value|
      @threshold = key
      @percent = value
    end
  end

  #returns the amount of the discount
  def apply(product, items_bought)
    if items_bought < @threshold
      0
    else
      percent = BigDecimal((@percent/100.to_f).to_s)
      discounted_items = BigDecimal((items_bought - @threshold).to_s)
      percent * discounted_items * product.price
    end
  end
end


class CouponUtil
  def self.get_coupon_instance(coupon_name, discount_hash)
    if discount_hash[:percent]
      PercentDiscountCoupon.new(coupon_name,discount_hash[:percent])
    else
      FixedAmountCoupon.new(coupon_name,discount_hash[:amount])
    end
  end

  def self.calculate_discount(total, old_total)
    total < 0 ? -old_total : total-old_total
  end
end

class BaseCoupon
  def use(cart_items)
    raise "this must be overriden"
  end
end

class PercentDiscountCoupon < BaseCoupon
  attr_reader :name, :percent
  def initialize(coupon_name, percent)
    @name = coupon_name
    @percent = percent
  end

  def use(total)
    percent = BigDecimal(((100 - @percent)/100.to_f).to_s)
    percent * total
  end
end

class FixedAmountCoupon < BaseCoupon
  attr_reader :name, :amount
  def initialize(coupon_name, discount_amount)
    @name = coupon_name
    @amount= discount_amount.to_d
  end

  def use(total)
    total - @amount
  end
end

class Inventory
  attr_reader :products, :coupons
  def initialize
    @products = {}
    @coupons = {}
  end

  def register(name, price, discount={})
    if not @products[name]
      @products[name] = Product.new(name, price, discount)
    end
  end

  def register_coupon(name, discount_hash)
    @coupons[name] = CouponUtil.get_coupon_instance(name, discount_hash)
  end

  def new_cart
    Cart.new self
  end
end

class Format
  def self.number(number)
    sprintf("%.2f", number)
  end

  def self.suffix(number)
    case number
    when 1
      suffix = "st"
    when 2
      suffix = "nd"
    when 3
      suffix = "rd"
    else
      suffix = "th"
    end
    number.to_s + suffix
  end
end

class DiscountUtil
  NAME_QTY_LENGTH = 48
  PRICE_LENGTH = 10
  def self.one_free_discount_to_s(product, items)
    items_to_buy = product.discount.item_at - 1 
    res = "|   (buy #{items_to_buy}, get 1 free)"
    res += " "  * (NAME_QTY_LENGTH - res.length + 1) + "|"
    discount =  Format.number(-product.discount.apply(product, items))
    res += " " * (PRICE_LENGTH - 1 - discount.to_s.length) + discount + " |\n"
    res
  end

  def self.package_discount_to_s(product,qty)
    percent = product.discount.percent
    for_every = product.discount.discount_for_every 
    res = "|   (get #{percent}% off for every #{for_every})"
    res += " " * (NAME_QTY_LENGTH  - res.length + 1) + "|"
    discount = Format.number(-product.discount.apply(product,qty))
    res += (" " * (PRICE_LENGTH - 1 - discount.to_s.length)) + discount +" |\n"
    res 
  end

  def self.amount_discount_to_s(product,qty)
    percent = product.discount.percent
    threshold = product.discount.threshold
    res = "|   (#{percent}% off of every after the #{Format.suffix threshold})"
    res += " " * (NAME_QTY_LENGTH - res.length + 1) + "|"
    discount = Format.number(-product.discount.apply(product,qty))
    res += (" " * (PRICE_LENGTH - 1 - discount.to_s.length)) + discount + " |\n"
    res
  end
end

class InvoiceUtil
  NAME_QTY_LENGTH = 48
  PRICE_LENGTH = 10
  def self.product_to_s(product, qty)
    res = "| " + product.name + (" " * get_name_blank_spaces(product.name, qty))
    res += qty.to_s+" |"
    res += " " * get_price_blank_spaces(product.price * qty)
    res +=  Format.number((product.price * qty).to_f) + " |\n"
    res += attach_product_promotions(product, qty)
    res
  end

  def self.total_to_s(total)
    res = "| TOTAL                                          |"
    formatted_total = Format.number(total.to_f)
    res += " " * get_price_blank_spaces(total) + formatted_total + " |\n"
    res
  end

  def self.coupon_to_s(coupon, discount)
    res = "| Coupon " + coupon.name + " - "
    if coupon.kind_of? FixedAmountCoupon
      res += Format.number(coupon.amount.to_f) + " off"
    else
      res += coupon.percent.to_s + "% off"
    end
    blank_spaces = NAME_QTY_LENGTH - res.length + 1
    res += " " * blank_spaces + "|"
    res += " " * get_price_blank_spaces(discount)
    res += Format.number(discount.to_f)  + " |\n"
    res
  end

  private 
  def self.get_price_blank_spaces(price)
    PRICE_LENGTH - Format.number(price.to_f).length - 1
  end

  def self.get_name_blank_spaces(name, qty)
    NAME_QTY_LENGTH - name.length - qty.to_s.length - 2
  end

  def self.attach_product_promotions(product, qty)
    if not product.discount
      ""
    elsif product.discount.kind_of? OneFreeDiscount
      DiscountUtil.one_free_discount_to_s(product,qty)
    elsif product.discount.kind_of? PackageDiscount
      DiscountUtil.package_discount_to_s(product,qty)
    elsif product.discount.kind_of? AmountDiscount
      DiscountUtil.amount_discount_to_s(product,qty)
    end
  end
end

class Cart
  INVOICE_SEPARATOR = "+" + "-" * 48 + "+----------+\n"
  INVOICE_HEADER = "| Name" + " " * 39 + "qty |    price |\n"
  attr_reader :items, :inventory
  def initialize(inventory)
    @inventory = inventory
    @items = {}
    @total = BigDecimal(0.to_s)
    @coupons = {}
  end

  def add(product_name, quantity = 1)
    Validate.product(product_name, @inventory)
    Validate.product_quantity(product_name, quantity,self)
    if not @items[product_name]
      @items[product_name] = quantity
    else
      @items[product_name] += quantity
    end
  end

  def use(coupon_name)
    if not @inventory.coupons[coupon_name]
      raise "No such coupon"
    else
      @coupons[coupon_name] = 0
    end
  end

  def total
    @total = "0".to_d
    @items.each do |key, value|
      @total += calculate_product_total(@inventory.products[key], value)
    end
    apply_coupons
    if @total < 0
      @total = "0.00".to_d
    end
    @total
  end

  def invoice 
    @total = total
    result = INVOICE_SEPARATOR + INVOICE_HEADER + INVOICE_SEPARATOR
    result += attach_products_and_coupons
    result +=INVOICE_SEPARATOR+InvoiceUtil.total_to_s(@total) +INVOICE_SEPARATOR
    result
  end

  def attach_products_and_coupons
    result = ""
    @items.each do |key, value|
      result += InvoiceUtil.product_to_s(@inventory.products[key], value)
    end
    @coupons.each do |coupon, discount|
      result += InvoiceUtil.coupon_to_s(@inventory.coupons[coupon], discount)
    end
    result
  end

  def apply_coupons
    @coupons.each do |coupon, discount_amount|
      old_total = @total
      @total = @inventory.coupons[coupon].use(@total)
      @coupons[coupon] = CouponUtil.calculate_discount(@total, old_total)
    end
  end

  def calculate_product_total(product, quantity)
    product.calculate_product_total(quantity)
  end
end

class Validate
  def self.product_quantity(product_name, qty, cart)
      if qty < 0 or qty > 99
        raise "Bad product quantity"
      end
      if not cart.items[product_name]
        return
      end
      if cart.items[product_name] + qty < 0
        raise "Too few items of this kind in the cart"
      elsif cart.items[product_name] + qty > 99
        raise "Too many items of this kind in the cart"
      end
  end

  def self.product(product_name, inventory)
    if not inventory.products[product_name]
      raise "No such product in the inventory"
    end
  end

  def self.product_name_length(product_name)
    if product_name.length > 40
      raise "Product name is too long"
    end
  end

  def self.product_price(product_price)
    parsed_price = product_price.to_d
    if parsed_price < 0.01 or parsed_price > 999.99
      raise "Incorrect product price"
    end
  end
end
