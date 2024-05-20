#!/bin/bash

# 设置检测的网络接口
INTERFACE="eno1"

# 定义网络测试的IP地址（例如Google的公共DNS）
TEST_IP="8.8.8.8"

# 检查网络接口状态
check_interface() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 检查接口 $INTERFACE"
    if ! ip link show $INTERFACE | grep -q "state UP"; then
        echo "$INTERFACE is 下线"
        return 1
    else
        echo "$INTERFACE is 上线"
        return 0
    fi
}

# 尝试ping一个外部IP地址来确认网络连通性
network_ping_test() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 执行 ping 测试 $TEST_IP"
    #if ping -c 1 -W 1 $TEST_IP &> /dev/null; then #设置为1秒，从而加快失败响应的速度
    if ping -c 1 $TEST_IP &> /dev/null; then
        echo "ping 至 $TEST_IP 成功"
        return 0
    else
        echo "ping to $TEST_IP 失败"
        return 1
    fi
}

# 重启网络服务
restart_networking() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 重新启动网络服务..."
    sudo systemctl restart networking
    echo "网络服务已重新启动."
}

# 系统重启
restart_system() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 重启系统..."
    sudo systemctl reboot
}

# 初始化故障计数器
failure_count=0

# 主循环
while true; do
    if check_interface && network_ping_test; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - 检测到 $INTERFACE. 正常"
        failure_count=0 # 重置计数器
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') - 检测到 $INTERFACE. 尝试重新启动网络服务..."
        restart_networking
        # 重启网络服务后再次检测
        if check_interface && network_ping_test; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 重启网络服务后问题解决."
            failure_count=0 # 重置计数器
        else
            ((failure_count++)) # 增加计数器
            if [ $failure_count -ge 2 ]; then
                echo "$(date +'%Y-%m-%d %H:%M:%S') - 重新启动网络服务后问题仍然存在，尝试重新启动系统..."
                restart_system
                break
            else
                echo "$(date +'%Y-%m-%d %H:%M:%S') - 重新启动网络服务后问题仍然存在，将重试..."
            fi
        fi
    fi
    sleep 3 # 每3秒运行一次检查
done
