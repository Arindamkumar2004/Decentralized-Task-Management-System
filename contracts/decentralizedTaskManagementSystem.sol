// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TaskManager {
    
    // Struct to represent a task
    struct Task {
        uint256 id;
        string title;
        string description;
        address creator;
        address assignee;
        uint256 reward;
        bool isCompleted;
        bool isPaid;
        uint256 createdAt;
        uint256 deadline;
    }
    
    // State variables
    uint256 private taskCounter;
    mapping(uint256 => Task) public tasks;
    mapping(address => uint256[]) public userTasks;
    mapping(address => uint256[]) public assignedTasks;
    
    // Events
    event TaskCreated(uint256 indexed taskId, address indexed creator, string title, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed assignee);
    event TaskCompleted(uint256 indexed taskId, address indexed assignee, uint256 reward);
    
    // Modifiers
    modifier onlyTaskCreator(uint256 _taskId) {
        require(tasks[_taskId].creator == msg.sender, "Only task creator can perform this action");
        _;
    }
    
    modifier onlyAssignee(uint256 _taskId) {
        require(tasks[_taskId].assignee == msg.sender, "Only assigned user can perform this action");
        _;
    }
    
    modifier taskExists(uint256 _taskId) {
        require(_taskId <= taskCounter && _taskId > 0, "Task does not exist");
        _;
    }
    
    // Core Function 1: Create a new task
    function createTask(
        string memory _title,
        string memory _description,
        uint256 _deadline
    ) external payable returns (uint256) {
        require(bytes(_title).length > 0, "Task title cannot be empty");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(msg.value > 0, "Task must have a reward");
        
        taskCounter++;
        
        tasks[taskCounter] = Task({
            id: taskCounter,
            title: _title,
            description: _description,
            creator: msg.sender,
            assignee: address(0),
            reward: msg.value,
            isCompleted: false,
            isPaid: false,
            createdAt: block.timestamp,
            deadline: _deadline
        });
        
        userTasks[msg.sender].push(taskCounter);
        
        emit TaskCreated(taskCounter, msg.sender, _title, msg.value);
        
        return taskCounter;
    }
    
    // Core Function 2: Assign task to a user
    function assignTask(uint256 _taskId, address _assignee) 
        external 
        taskExists(_taskId) 
        onlyTaskCreator(_taskId) 
    {
        require(_assignee != address(0), "Invalid assignee address");
        require(tasks[_taskId].assignee == address(0), "Task already assigned");
        require(!tasks[_taskId].isCompleted, "Task already completed");
        require(block.timestamp < tasks[_taskId].deadline, "Task deadline has passed");
        
        tasks[_taskId].assignee = _assignee;
        assignedTasks[_assignee].push(_taskId);
        
        emit TaskAssigned(_taskId, _assignee);
    }
    
    // Core Function 3: Mark task as completed and transfer reward
    function completeTask(uint256 _taskId) 
        external 
        taskExists(_taskId) 
        onlyAssignee(_taskId) 
    {
        Task storage task = tasks[_taskId];
        
        require(!task.isCompleted, "Task already completed");
        require(block.timestamp <= task.deadline, "Task deadline has passed");
        require(!task.isPaid, "Reward already paid");
        
        task.isCompleted = true;
        task.isPaid = true;
        
        // Transfer reward to assignee
        (bool success, ) = payable(task.assignee).call{value: task.reward}("");
        require(success, "Payment transfer failed");
        
        emit TaskCompleted(_taskId, task.assignee, task.reward);
    }
    
    // Helper function: Get task details
    function getTask(uint256 _taskId) 
        external 
        view 
        taskExists(_taskId) 
        returns (Task memory) 
    {
        return tasks[_taskId];
    }
    
    // Helper function: Get tasks created by user
    function getUserTasks(address _user) external view returns (uint256[] memory) {
        return userTasks[_user];
    }
    
    // Helper function: Get tasks assigned to user
    function getAssignedTasks(address _user) external view returns (uint256[] memory) {
        return assignedTasks[_user];
    }
    
    // Helper function: Get total number of tasks
    function getTotalTasks() external view returns (uint256) {
        return taskCounter;
    }
    
    // Emergency function: Allow task creator to withdraw funds if task is not completed after deadline
    function withdrawExpiredTask(uint256 _taskId) 
        external 
        taskExists(_taskId) 
        onlyTaskCreator(_taskId) 
    {
        Task storage task = tasks[_taskId];
        
        require(!task.isCompleted, "Task is already completed");
        require(!task.isPaid, "Reward already paid");
        require(block.timestamp > task.deadline, "Task deadline has not passed yet");
        
        task.isPaid = true; // Prevent re-entrancy
        
        (bool success, ) = payable(task.creator).call{value: task.reward}("");
        require(success, "Withdrawal failed");
    }
}
