module Watchcat
  class RootKind
    def access?
      false
    end

    def create?
      false
    end

    def modify?
      false
    end

    def remove?
      false
    end

    def other?
      false
    end
  end

  class AccessKind < RootKind
    def access?
      true
    end
  end

  class CreateKind < RootKind
    def create?
      true
    end
  end

  class ModifyKind < RootKind
    def modify?
      true
    end
  end

  class RemoveKind < RootKind
    def remove?
      true
    end
  end

  class OtherKind < RootKind
    def other?
      true
    end
  end
end
