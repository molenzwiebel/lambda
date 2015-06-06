
module Lambda
    def run(src)
        Lambda.run src
    end

    def self.run(src)
        env = Scope.new
        env.def_var("print", ->(x) {
            raise "print takes 1 argument, #{x.size} given" unless x.size == 1
            print(x[0].chr) unless x[0].is_a?(Proc)
            return 0
        })

        env.def_var("file_open", ->(loc) {
            # We assume we received a cons() list.
            str = ""
            cell = loc[0]
            until cell.call([1, 0]).is_a?(Proc)
                str += cell.call([1, 0]).chr
                cell = cell.call([1, 1])
            end

            return File.open(str, "r")
        })

        env.def_var("file_read", ->(file) {
            return file[0].getc().ord
        })

        env.def_var("file_iseof", ->(file) {
            return file[0].eof ? 1 : 0
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
            if node.op == "=" then
                existing = env.has(node.left.name)
                val = evaluate(node.right, env)
                return existing ? env.set(node.left.name, val) : env.def_var(node.left.name, val)
            end
            perform_binary node, env
        when LambdaDef
            create_lambda node, env
        when If
            cond = evaluate(node.cond, env)
            return evaluate(node.if_body, env) if cond != 0
            return evaluate(node.else_body, env) if node.else_body
        when Call
            func = evaluate(node.target, env)
            node.raise "Cannot call non-function" unless func.is_a?(Proc)
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
        when "%"
            left % right
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
        when "&&"
            (left == 1 && right == 1) ? 1 : 0
        when "||"
            (left == 1 || right == 1) ? 1 : 0
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
