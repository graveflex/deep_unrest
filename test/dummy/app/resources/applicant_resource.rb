class ApplicantResource < BaseResource
  attributes :name,
             :nickname,
             :email

  def self.records(opts)
    results = super(opts)
    results.where('nickname IS NOT ?', '_stimpy_')
  end
end
