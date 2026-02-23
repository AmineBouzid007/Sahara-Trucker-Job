// ==========================================
// [01] GLOBAL STATE
// ==========================================
let jobList = [];
let myServerID = null;
let currentConvoyID = null;
let isLeader = false;
let playerLevel = 1;
let currentJobId = null;

// ==========================================
// [02] INITIALIZATION
// ==========================================
$(document).ready(function () {
    // Hide UI elements initially
    $('#ui-wrapper, .popUp, .page-container').hide();
    $('#jobsPage').show(); 

    // Holographic Nav
    $('.nav-item').on('click', function() {
        const targetPage = $(this).data('page');
        $('.nav-item').removeClass('active');
        $(this).addClass('active');
        $('.page-container').hide(); 
        $('#' + targetPage).fadeIn(250);
    });

    // Terminal Shutdown
    $('#closeBtn, .closeIcon').on('click', function() { closeMenu(); });

    // Authorization Decision
    $('#cancel').on('click', function() { $('.popUp').fadeOut(200); });

    $('#confirm').on('click', function() {
        if (!currentJobId) return;
        const selectedJob = jobList.find(function(j) { return j.id === currentJobId; });
        if (!selectedJob) return;

        $.post('https://' + GetParentResourceName() + '/startJob', JSON.stringify({
            jobId: selectedJob.id,
            jobType: selectedJob.type,
            convoyID: currentConvoyID 
        }));

        $('.popUp').fadeOut(200);
        closeMenu();
    });

    // Dropdown Logic
    $('.filterMenu').on('click', function() { $('.menu-items').fadeToggle(150); });

    // Sorting Handlers
    $('#asc').on('click', function() { jobList.sort((a,b) => a.totalPrice - b.totalPrice); loadJobs(); });
    $('#desc').on('click', function() { jobList.sort((a,b) => b.totalPrice - a.totalPrice); loadJobs(); });
    $('#farthest').on('click', function() { jobList.sort((a,b) => b.distance - a.distance); loadJobs(); });
    $('#shortest').on('click', function() { jobList.sort((a,b) => a.distance - b.distance); loadJobs(); });

    // Terminal Search
    $('#trailerInput').on('keyup', function() {
        const val = $(this).val().toLowerCase();
        $(".trailerItem").each(function() {
            $(this).toggle($(this).text().toLowerCase().indexOf(val) > -1);
        });
    });
});

// ==========================================
// [03] NUI MESSAGE HANDLER
// ==========================================
window.addEventListener('message', function (event) {
    const data = event.data;

    switch (data.action) {
        case "openUI":
            myServerID = data.serverID;
            // COMBINE ALL JOB SOURCES
            const staticJobs = data.jobs || [];
            const dynamicJobs = data.randomJobs || [];
            jobList = staticJobs.concat(dynamicJobs);

            if (data.player) {
                $('#playerName').text("USER_REF: " + data.player.name);
                updateLevelUI(data.player.xp, data.player.level);
            }
            loadJobs();
            $('#ui-wrapper').css('display', 'flex').hide().fadeIn(400);
            break;

        case "updateConvoyPlayers":
            currentConvoyID = data.convoyID || currentConvoyID;
            const members = data.members || [];
            const me = members.find(m => m.id === myServerID);
            isLeader = me && (me.isLeader || (me.name && me.name.includes("(Leader)")));
            
            if (currentConvoyID) {
                $('#convoyAuth').hide();
                $('#convoyLobby').fadeIn(300);
                $('#activeConvoyID').text("#" + currentConvoyID);
                renderLobbyPlayers(members);
            }
            loadJobs(); 
            break;

        case "syncConvoyJob":
            if (data.jobData) {
                currentJobId = data.jobData.id;
                updateLobbyMission(data.jobData);
                loadJobs(); 
            }
            break;

        case "resetConvoy":
            resetConvoyUI();
            break;
            
        case "close":
            closeMenu();
            break;
    }
});

// ==========================================
// [04] CONVOY INTERFACE FUNCTIONS
// ==========================================
$('#createConvoyBtn').on('click', function() {
    $.post('https://' + GetParentResourceName() + '/createConvoy', JSON.stringify({}));
});

$('#joinConvoyBtn').on('click', function() {
    const id = $('#joinIDInput').val();
    if (id) $.post('https://' + GetParentResourceName() + '/joinConvoy', JSON.stringify({ convoyID: id }));
});

$('#leaveConvoyBtn').on('click', function() {
    $.post('https://' + GetParentResourceName() + '/leaveConvoy', JSON.stringify({}));
    resetConvoyUI();
});

function resetConvoyUI() {
    currentConvoyID = null; isLeader = false; currentJobId = null;
    $('#convoyLobby').hide();
    $('#convoyAuth').fadeIn(300);
    updateLobbyMission(null);
    loadJobs();
}

function renderLobbyPlayers(players) {
    const container = $('#playerList'); container.empty();
    players.forEach(p => {
        container.append('<div class="player-row"><span>' + p.name + '</span><span class="player-id">[SIG_' + p.id + ']</span></div>');
    });
}

// ==========================================
// [05] DATA RENDERING ENGINE
// ==========================================
function loadJobs() {
    const container = $('#jobListArea');
    container.empty();

    if (currentConvoyID && !isLeader) {
        container.append('<div class="job-lock-overlay"><span>WAITING FOR SQUAD LEADER...</span></div>');
    }

    jobList.forEach(function(job) {
        const reqRank = job.level || 1;
        const isLocked = playerLevel < reqRank;
        const activeClass = (currentJobId === job.id) ? 'active' : '';
        
        let itemHtml = '<div class="trailerItem ' + (isLocked ? 'locked' : '') + ' ' + activeClass + '" data-id="' + job.id + '">';
        if (isLocked) { 
            itemHtml += '<div class="locked-overlay" data-level-text="REQUIRED RANK: ' + reqRank + '"></div>'; 
        }
        itemHtml += '<div class="trailerImg"><img src="' + job.imgSrc + '"></div>';
        itemHtml += '<div class="trailerInfo"><div class="trailerName">' + job.name + '</div>';
        itemHtml += '<div class="trailerRoute">SECTOR: ' + (job.streetNames || "INDUSTRIAL") + '</div></div>';
        itemHtml += '<div class="trailerStats"><div class="trailerPrice">$' + job.totalPrice + '</div>';
        itemHtml += '<div class="trailerDist">' + (job.distance || "5.0") + ' KM</div></div></div>';

        const $item = $(itemHtml);
        $item.on('click', function() {
            if (isLocked || (currentConvoyID && !isLeader)) return;
            currentJobId = job.id;
            $('.trailerItem').removeClass('active'); $(this).addClass('active');
            $.post('https://' + GetParentResourceName() + '/selectJob', JSON.stringify({ convoyID: currentConvoyID, jobData: job }));
            $('.popUpText').html('AUTHORIZE CONTRACT: <span style="color:#00d2ff">' + job.name + '</span>?');
            $('.popUp').fadeIn(250);
        });
        container.append($item);
    });
}

function updateLevelUI(xp, level) {
    playerLevel = level;
    $('#levelStatus').css('width', xp + '%');
    $('#levelText').text('RANK ' + level + ' [' + xp + '/100 XP]');
}

function updateLobbyMission(job) {
    if (!job) { $('#lobbyMissionInfo').html('<div class="no-mission">WAITING_FOR_UPLINK...</div>'); return; }
    $('#lobbyMissionInfo').html('<div class="mission-active-card"><div style="color:var(--accent); font-family:Oswald;">' + job.name + '</div><div style="font-size:10px; opacity:0.5;">UPLINK_SUCCESS</div></div>');
}

function closeMenu() {
    $('#ui-wrapper, .popUp').fadeOut(250, function() { $(this).hide(); });
    $.post('https://' + GetParentResourceName() + '/closeUI', JSON.stringify({}));
}
