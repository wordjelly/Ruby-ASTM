bytes = [2, 49, 72, 124, 96, 94, 38, 124, 124, 124, 124, 124, 124, 124, 124, 124, 124, 80, 124, 69, 32, 49, 51, 57, 52, 45, 57, 55, 124, 50, 48, 49, 56, 49, 49, 50, 51, 49, 54, 53, 52, 50, 53, 13, 81, 124, 49, 124, 94, 48, 49, 48, 51, 50, 48, 49, 56, 51, 124, 124, 124, 83, 124, 124, 124, 124, 124, 124, 124, 79, 13, 76, 124, 49, 124, 78, 13, 3, 57, 54, 13, 10]
puts bytes.pack('c*')



def achecksum(input)
    strString = input
    checksum = strString.sum
    #puts checksum
    b = checksum.to_s(16)
    strCksm = b[-2..-1]
    if strCksm.length < 2 
      for i in strString.length..1
         strCksm = "0" + strCksm
      end
    end
    puts strCksm
    strCksm
end


def checksum(string)
	#string = "1H|`^&||||||||||P|E 1394-97|20181120154015\rP|1|0||||||F||||||||0|0\rO|1|Asha Singh^03^1^1||^^^GLU|||||||||||SERUM\rR|1|^^^GLU|115.5|mg/dl|^DEFAULT|H|N|F||||20181120150433\rC|1|I|Instrument Flag H\rL|1|N\r"
	#string = "1H|`^&||||||||||P|E 1394-97|20181120154033\rP|1|0||||||U||||||||0|0\rO|1|Asha Singh1^03^1^2||^^^CRE|||||||||||SERUM\rR|1|^^^CRE|0.75|mg/dl|^DEFAULT|N|N|F||||20181120150451\rC|1|I|Instrument Flag N\rL|1|N\r"

	sum = 0
	for i in 0..(string.length - 1) do
		sum += string[i].ord;
		puts "string[i] is: #{string[i]} -- ord is: #{string[i].ord} sum is: #{sum}"
	end
	
	#sum += 16; 
	puts "sum is : #{sum}"
	sum = sum % 8;
	checksum = sum.to_s(32).upcase
	if (checksum.length == 1) 
	    checksum = "0" + checksum;
	end
	checksum
end

string = bytes.pack('c*')[1..-5]
puts string.to_s
string = "1H|`^&||||||||||P|E 1394-97|20181122140918\rQ|1|^010520182|||S|||||||O\rL|1|N\r"
csum = 96
ourcsum = achecksum(string)
puts "ourcsum is: #{ourcsum}"


## 1 -- -6




=begin
find checksum using their method
strString = "who the fook is that guyyy"

checksum= 0

for i in 0..strString.length-1
	g = i +1
	if strString[i..i]==''
		checksum = checksum + 32
	else
		puts strString[i..i]
	checksum = checksum + strString[i..i].ord
	end
end
=end

