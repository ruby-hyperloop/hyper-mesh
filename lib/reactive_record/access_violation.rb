module ReactiveRecord
  class AccessViolation < StandardError
    def message
      "ReactiveRecord::AccessViolation: #{super}"
    end
  end
end