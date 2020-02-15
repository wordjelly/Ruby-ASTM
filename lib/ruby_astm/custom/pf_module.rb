module PfModule
	include LabInterface

	def self.included base
    	base.extend ClassMethods
  	end

  	def process_type(line)
      case line.type
      when "Hl7_Header"
        hl7_header = Hl7Header.new({:line => line})
        self.headers ||= []
        self.headers << hl7_header
      when "Hl7_Observation"
        unless self.headers.blank?
          unless self.headers[-1].patients.blank?
            unless self.headers[-1].patients[-1].orders[-1].blank?
              hl7_observation = Hl7Observation.new({:line => line})
              self.headers[-1].patients[-1].orders[-1].results[hl7_observation.name] ||= hl7_observation
            end
          end
        end
      when "Hl7_Patient"
        hl7_patient = Hl7Patient.new({:line => line})
        self.headers[-1].patients << hl7_patient
      when "Hl7_Order"
        unless self.headers[-1].patients.blank?
          hl7_order = Hl7Order.new({:line => line, :patient_id => self.headers[-1].patients[-1].patient_id, :machine_name => self.headers[-1].machine_name})
          self.headers[-1].patients[-1].orders << hl7_order
        end
      when "Header"
        #puts "got header"
        header = Header.new({:line => line})
        self.headers ||= []
        self.headers << header
      when "Query"
        #puts "got query, what is the query class: #{self.query_class}"
        #self.query_class ||= "Query"
        #puts "the query class is: #{self.query_class}"
        query = PfQuery.new({:line => line})
        unless self.headers.blank?
          self.headers[-1].queries << query
        end
      when "Patient"
        #puts "got patient."
        patient = Patient.new({:line => line})
        unless self.headers.blank?
          self.headers[-1].patients << patient
        end
      when "Order"
        order = Order.new({:line => line})
        unless self.headers.blank?
          unless self.headers[-1].patients.blank?
            self.headers[-1].patients[-1].orders << order
          end
        end
      when "Result"
        #puts "GOT RESULT------------------>"
        #puts "line is :#{line}"
        result = Result.new({:line => line})
        #puts "made new result"
        unless self.headers.blank?
          unless self.headers[-1].patients.blank?
            unless self.headers[-1].patients[-1].orders[-1].blank?
              self.headers[-1].patients[-1].orders[-1].results[result.name] ||= result
            end
          end
        end
      when "Terminator"
        ## it didn't terminate so there was no commit being called.
        unless self.headers.blank?
          #puts "got terminator."
          self.headers[-1].commit
        end
      end
  end

end