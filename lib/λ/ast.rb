
module Molen
    class Visitor
        def visit_any(node)
            nil
        end
    end

    class ASTNode
        attr_accessor :filename, :line

        def self.attrs(*fields)
            attr_accessor *fields

            define_method "==" do |other|
                return false unless other.class == self.class
                eq = true
                fields.each do |field|
                    eq &&= self.send(field) == other.send(field)
                end
                return eq
            end

            class_eval %Q(
                def initialize(#{fields.map(&:to_s).join ", "})
                    #{fields.map(&:to_s).map{|x| x.include?("body") ? "@#{x} = Body.from #{x}" : "@#{x} = #{x}"}.join("\n")}
                end
            )
        end

        def self.inherited(klass)
            name = klass.name.split('::').last.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').tr("-", "_").downcase

            klass.class_eval %Q(
                def accept(visitor)
                    visitor.visit_any(self) || visitor.visit_#{name}(self)
                end
            )

            Visitor.class_eval %Q(
                def visit_#{name}(node)
                    nil
                end
            )
        end

        def raise(msg)
            Kernel::raise "#{filename}##{line}: #{msg}"
        end
    end

    class Body < ASTNode
        include Enumerable
        attrs :contents

        def self.from(other)
            return Body.new [] if other.nil?
            return other if other.is_a? Body
            return Body.new other if other.is_a? ::Array
            Body.new [other]
        end

        def each(&block)
            contents.each &block
        end
    end

    class Ident < ASTNode
        attrs :name
    end

    class Num < ASTNode
        attrs :value
    end

    class Binary < ASTNode
        attrs :left, :op, :right
    end

    class Lambda < ASTNode
        attrs :args, :body
    end

    class Call < ASTNode
        attrs :target, :args
    end

    class If < ASTNode
        attrs :cond, :if_body, :else_body
    end
end
