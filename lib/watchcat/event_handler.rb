module Watchcat
  class EventHandler
    def dispatch(event)
      on_any_event(event)

      kind = event.kind
      if kind.create?
        on_create(event)
      elsif kind.remove?
        on_remove(event)
      elsif kind.modify?
        if kind.modify.rename?
          on_rename(event)
        else
          on_modify(event)
        end
      elsif kind.access?
        on_access(event)
      end
    end

    def on_any_event(event); end
    def on_create(event); end
    def on_modify(event); end
    def on_remove(event); end
    def on_rename(event); end
    def on_access(event); end
  end
end
