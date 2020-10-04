# raft疑难问题汇总

### question1：为什么raft协议中，leader只能提交当前任期的日志，不能提交其他任期的日志？

### answer1：


### **question2：raft协议中，提出的两个假设是什么？**

> 每次同步事件时，有以上3个村落都有着从开始到当前页码相同的记录时，才算安全，才能把这个事件记录到石碑上
> 主家记录每个客家最后记录下来的第几页的数据就可以了matchIndex  

### **answer2：**

1. 数据流向只能由leader发送follower  
2. 数据不能有空洞 

### question3：raft协议怎么定义消息相同？

### answer3： 