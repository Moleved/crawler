require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'phone'
require 'csv'

def parse_URL(url, type)

  headers = ['date of event', 'finishers number', 'ville de depart', 'email', 'tel', 'link', 'distance']

  filename = 'parsed' + type + '.csv'
  CSV.open(filename, 'ab') do |csv|
    csv << headers
  end

  phones = []
  emails = []
  links = []
  dates = []
  names = []
  departure = []
  finishers = []
  distance = []

  html_data = open(url).read
  web_page = Nokogiri::HTML(html_data)
  tr_elements = web_page.xpath('//tr')
  a_elements = web_page.xpath('//tr/td/a/text()')
  url_elements = web_page.xpath('//tr/td/a')
  distance_elements = web_page.xpath('//em')

  for element in tr_elements
    date, = element.xpath('./td')
    dates.push(date.text)
  end

  dates.delete('Aucune épreuve trouvée')
  dates = dates[0..-3]

  for element in a_elements
    names.push(element.text)
  end

  for element in distance_elements
    distance.push(element.text) if (element.text.include? 'Marathon' or element.text.include? 'km' or element.text.include? 'Semi')
  end

  for element in url_elements
    if element['href'].include? 'presentation'
      temp_emails = []
      temp_phones = []

      link = element['href']
      html_data = open(link).read
      web_page = Nokogiri::HTML(html_data)

      departure_nodes = web_page.xpath('//*[@id="bloc-info-valeur"]')
      _, second_div = web_page.xpath('//*[@id="bloc-info-label"]')
      metadata = web_page.xpath('//*[@id="bloc-gauche3"]')
      metadata_splited = metadata.text.split

      for element in metadata_splited
        if element.include? '@'
          temp_emails.push(element[0..-2])
        end
      end

      link = web_page.xpath('//*[@id="bloc-gauche3"]/a')
      n_finishers = second_div.text

      if n_finishers.include? 'finishers'
        finishers.push(n_finishers)
      else
        finishers.push('no data')
      end

      departure.push(departure_nodes.text)

      if link.length == 1
        links.push(link[0]['href'])
      else
        links.push('no data')
      end

      for element in metadata.text.split('//')
        Phoner::Phone.default_country_code = '33'
        Phoner::Phone.default_area_code = '0'
        pn = Phoner::Phone.parse(element)
        pn.nil? ? temp_phones.push('no data') : temp_phones.push(pn.format(:europe))
      end

      temp_emails.length == 0 ? emails.push('no data') : emails.push(temp_emails)
      temp_phones.length == 0 ? phones.push('no data') : phones.push(temp_phones)
    end
  end

  for i in 0..dates.length-1
    data = []
    data.push(dates[i])
    data.push(finishers[i])
    data.push(departure[i])
    emails[i].length>1 ? data.push(emails[i].join('/')) : data.push(emails[i][0])
    phones[i].length>1 ? data.push(phones[i].join('/')) : data.push(phones[i][0])
    data.push(links[i])
    data.push(distance[i])
    # data.push(names[i])

    CSV.open(filename, 'ab') do |csv|
      csv << data
    end
  end
end

parse_URL(URL_0, 'marathon1')
parse_URL(URL_1, 'semimarathon1')
