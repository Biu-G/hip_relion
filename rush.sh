#!/bin/bash
#ReadAllFileName.sh
#获取目录下的所有 .c .cpp文件
# 本脚本放在 要获取文件的目录下

thread_num=39
# mkfifo
tempfifo="my_temp_fifo"
mkfifo ${tempfifo}
# 使文件描述符为非阻塞式
exec 6<>${tempfifo}
rm -f ${tempfifo}

# 为文件描述符创建占位信息
for ((i=1;i<=${thread_num};i++))
do
{
    echo 
}
done >&6 

 
cd `dirname $0`
 
result=''
 
function ReadAllFileName()
{
  if [ "X$1" != 'X' ]
   then
         cd "$1"
  fi
  
  files=`ls`
for filename in $files;do
	
	if [ -d $filename ]
    	then
		echo  "文件夹 $filename "
	        #递归
		ReadAllFileName $filename 
	else
 
	if [ ${filename##*.} = 'h' ] || [ ${filename##*.} = 'cuh' ] || [ ${filename##*.} = 'cpp' ] || [ ${filename##*.} = 'cu' ]
	 then
		echo $filename
		{
			result=${result}"\n"$filename
			hipify-perl -inplace $filename
			echo "" >&6
		}&
	fi
	
	fi
done
	cd ..	
}
 
ReadAllFileName

wait

exec 6>&- 
 
#echo -e $result

