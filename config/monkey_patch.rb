class String
	def blank?
		self =~ /^\s*$/
	end

	def is_i?
		/\A[-+]?\d+\z/ === self
	end
end