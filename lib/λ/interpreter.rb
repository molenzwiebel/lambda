
module Lambda
    def run(src)
        Lambda.run src
    end

    def self.run(src)
        env = Scope.new
        env.def_var("print", ->(x) {
            raise "Print takes 1 argument, #{x.size} given" unless x.size == 1
            #raise "Tried to print proc" if x[0].is_a?(Proc)
            print(x[0].chr) unless x[0].is_a?(Proc)
            return 0
        })

        evaluate parse(src), env
    end

    def evaluate(node, env)
        Lambda.evaluate node, env
    end

    def self.evaluate(node, env)
        case node
        when Body
            node.map { |n| evaluate(n, env) }.last
        when Num
            node.value
        when Ident
            env.get node.name
        when Binary
            return env.def_var(node.left.name, evaluate(node.right, env)) if node.op == "="
            perform_binary node, env
        when LambdaDef
            create_lambda node, env
        when If
            cond = evaluate(node.cond, env)
            return evaluate(node.if_body, env) if cond != 0
            return evaluate(node.else_body, env) if node.else_body
        when Call
            func = evaluate(node.target, env)
            func.call(node.args.map{|a| evaluate(a, env)})
        end
    end

    def self.perform_binary(node, env)
        left = evaluate(node.left, env)
        right = evaluate(node.right, env)
        case node.op
        when "+"
            left + right
        when "-"
            left - right
        when "*"
            left * right
        when "/"
            left / right
        when "=="
            left == right ? 1 : 0
        when "!="
            left != right ? 1 : 0
        when "<"
            left < right ? 1 : 0
        when "<="
            left <= right ? 1 : 0
        when ">"
            left > right ? 1 : 0
        when ">="
            left >= right ? 1 : 0
        end
    end

    def self.create_lambda(node, env)
        anon = lambda do |args|
            new_env = env.extend
            node.args.each_with_index { |n, i| new_env.def_var(n, args[i]) }
            return evaluate(node.body, new_env)
        end

        if node.name then
            env = env.extend
            env.def_var node.name, anon
        end

        return anon
    end
end
