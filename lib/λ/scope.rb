
module Lambda
    class Scope
        attr_accessor :vars, :parent

        def initialize(parent = nil)
            @vars = {}
            @parent = parent
        end

        def extend
            Scope.new self
        end

        def lookup(name)
            lookup_scope = self
            while lookup_scope
                return lookup_scope if lookup_scope.vars[name]
                lookup_scope = lookup_scope.parent
            end
            nil
        end

        def get(name)
            lookup(name).vars[name] || raise("Undefined variable #{name}")
        end

        def has(name)
            lookup_scope = lookup name
            return true if lookup_scope
            return false
        end

        def set(name, val)
            lookup_scope = lookup name
            raise "Undefined variable #{var}" if lookup_scope.nil? && parent
            lookup_scope.vars[name] = val
        end

        def def_var(name, val)
            vars[name] = val
        end
    end
end
